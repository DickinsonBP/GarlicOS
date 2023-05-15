@;==============================================================================
@;
@;	"garlic_itcm_mem.s":	código de rutinas de soporte a la carga de
@;							programas en memoria (version 1.0)
@;
@;==============================================================================

NUM_FRANJAS = 768
INI_MEM_PROC = 0x01002000


.section .dtcm,"wa",%progbits
	.align 2

	.global _gm_zocMem
_gm_zocMem:	.space NUM_FRANJAS			@; vector de ocupación de franjas mem de 32b.

_gm_zocalos:	.space 16

.section .itcm,"ax",%progbits

	.arm
	.align 2


	.global _gm_reubicar
	@; Rutina de soporte a _gm_cargarPrograma(), que interpreta los 'relocs'
	@; de un fichero ELF, contenido en un buffer *fileBuf, y ajustar las
	@; direcciones de memoria correspondientes a las referencias de tipo
	@; R_ARM_ABS32, a partir de las direcciones de memoria destino de código
	@; (dest_code) y datos (dest_data), y según el valor de las direcciones de
	@; las referencias a reubicar y de las direcciones de inicio de los
	@; segmentos de código (pAddr_code) y datos (pAddr_data)
	@;Parámetros:
	@; R0: dirección inicial del buffer de fichero (char *fileBuf)
	@; R1: dirección de inicio de segmento de código (unsigned int pAddr_code)
	@; R2: dirección de destino en la memoria (unsigned int *dest_code)
	@; R3: dirección de inicio de segmento de datos (unsigned int pAddr_data)
	@; (pila): dirección de destino en la memoria (unsigned int *dest_data)
	@;Resultado:
	@; cambio de las direcciones de memoria que se tienen que ajustar
_gm_reubicar:
	push {r3 - r12,lr}
	
	ldr r4, [r0, #32]	@;Desplazar 32 (=0x20) en la cabecera del archivo para obtener e_shoff
	add r4, r0			@;r4 es la direccion de la primera entrada de la tabla de secciones
	
	ldrh r5, [r0, #46]	@;Desplazar 46 (=0x2E) en la cabecera del archivo para obtener e_shentsize
	ldrh r6, [r0, #48]	@;Desplazar 48 (=0x30) en la cabecera del archivo para obtener e_shnum
	
	mov r12, #0			@;indice para el bucle de secciones
.LSecciones:
	ldr r7, [r4, #4]	@;Desplazar 4 (=0x4) en la tabla de secciones para obtener sh_type
	cmp r7, #9			@;if(sh_type == 9)
	beq .LReubicador	@;si la seccion es un reubicador
	b .LSiguienteSeccion

.LReubicador:
	ldr r9, [r4, #16]	@;Desplazar 16 (=0x10) en la tabla de secciones para obtener sh_offset
	
	push {r0 - r4}		@;guardar registros para hacer división
	
	ldr r0, [r4, #20]	@;Desplazar 20 (=0x14) en la tabla de secciones para obtener sh_size
	ldr r1, [r4, #36] 	@;Desplazar 36 (=0x24) en la tabla de secciones para obtener sh_entsize
	ldr r2, =_gd_quo
	ldr r3, =_gd_mod
	mov r10, r1			@;salvar sh_entsize
	bl _ga_divmod		@;Para tener el numero de reubicadores hay que dividir el tamaño de la sección y la medida de cada una
	ldr r8, [r2]		@;resultado de la división
	
	pop {r0 - r4}
	
	mov r11, #0			@;indice para el bulce de reubicadores
	
	push {r4 - r7}
	ldr r7, [sp,#60]	@;Sumar 60 al sp para obtener el quinto parametro.
	add r5, r0, r9		@;direccion de la seccion del reubicador
	
.LReubicadores:
	
	ldr r4, [r5,#4]		@;Desplazar 4 en la tabla de reubicadores para obtener r_info
	and r4,	#0xFF		@;Hacer and para obtener los bits bajos ya que contienen el tipo de reubicador
	
	cmp r4, #2			@;if(r4 != R_ARM_ABS32)
	bne .LNoReubicador
	
	ldr r4, [r5]		@;direccion a reubicar
	sub r4, r1			@;restarle la direccion inicial
	add r4, r2			@;sumarle la direccion destino
	
	cmp r3, #0
	bne .LEsDatos
	ldr r3, =0xFFFFFFFF	@;forzar valor si solo hay 1 segmento
	
.LEsDatos:
	ldr r6, [r4]		@;Direccion de memoria reubicada
	cmp r6, r3			@;Comprobar si es segmento de datos o de codigo
	@;mirando si esta en una posicion menor o mayor.
	
	sublo r6, r1		@;codigo
	addlo r6, r2
	
	subhs r6, r3		@;datos
	addhs r6, r7
	
	str r6, [r4]		@;guardar en memoria

.LNoReubicador:
	
	add r5, r10			@;Pasar al siguiente reubicador
	add r11, #1
	
	cmp r11, r8
	blo .LReubicadores
	
	pop {r4 - r7}
	
	
.LSiguienteSeccion:
	
	add r4, r5			@;Siguiente sección
	add r12, #1			@;Incrementar indice de secciones
	
	cmp r12, r6			@;if(r12 < e_shnum)
	blo .LSecciones
	
	pop {r3 - r12,pc}
	

	.global _gm_reservarMem
	@; Rutina de soporte a _gm_cargarPrograma(), que interpreta los 'relocs'
	@; de un fichero ELF, contenido en un buffer *fileBuf, y ajustar las
	@; direcciones de memoria correspondientes a las referencias de tipo
	@; R_ARM_ABS32, a partir de las direcciones de memoria destino de código
	@; (dest_code) y datos (dest_data), y según el valor de las direcciones de
	@; las referencias a reubicar y de las direcciones de inicio de los
	@; segmentos de código (pAddr_code) y datos (pAddr_data)
	@;Parámetros:
	@; R0: dirección inicial del buffer de fichero (char *fileBuf)
	@; R1: dirección de inicio de segmento de código (unsigned int pAddr_code)
	@; R2: dirección de destino en la memoria (unsigned int *dest_code)
	@; R3: dirección de inicio de segmento de datos (unsigned int pAddr_data)
	@; (pila): dirección de destino en la memoria (unsigned int *dest_data)
	@;Resultado:
	@; cambio de las direcciones de memoria que se tienen que ajustar
_gm_reservarMem:
	push {r1-r8,lr}
	mov r3,#0
	mov r4,r1		
.LFor:				@;Buscamos cuantos bloques del vector se necesitan
	sub r4,#32
	add r3,#1
	cmp r4,#0
	bgt .LFor

	ldr r4,=_gm_zocMem
	mov r5,#0		@;contador de franjas (r5<768)
	mov r6,#0		@;contador de franjas libres 
.LPerFranja:
	ldrb r7,[r4,r5]
	cmp r7,#0
	addeq r6,#1
	movne r6,#0
	cmp r6,#1		@;Si se encuentra una posición libre se guarda la posición
	moveq r8,r5	
	cmp r6,r3		@;Si se encuentra un espacio suficientemente grande
	beq .LHayEspacio
	add r5,#1
	cmp r5,#NUM_FRANJAS
	blt .LPerFranja
	b .LNoEspacio
.LHayEspacio:
	mov r5,#0
	add r4,r8		@;Nos situamos en la primera franja
.LIntroduceFranja:
	strb r0,[r4,r5]
	add r5,#1
	cmp r5,r3
	blt .LIntroduceFranja
	mov r1,r8
	mov r3,r2
	mov r2,r6
	bl _gm_pintarFranjas
	ldr r6,=INI_MEM_PROC
	add r5,r6,r8,lsl#5
	mov r0,r5
	b .LFin
.LNoEspacio:
	mov r0,#0
.LFin:
	
	pop {r1-r8,pc}

	
	.global _gm_liberarMem
	@; Rutina para liberar todas las franjas de memoria asignadas al proceso
	@; del zócalo indicado por parámetro; también se encargará de invocar a la
	@; rutina _gm_pintarFranjas(), para actualizar la representación gráfica
	@; de la ocupación de la memoria de procesos.
	@;Parámetros:
	@;	R0: el número de zócalo que libera la memoria
_gm_liberarMem:
	push {r1-r9,lr}
	ldr r1,=_gm_zocMem
	mov r2,#0			@;Contador de franjas
	ldr r3,=NUM_FRANJAS
	mov r4,#0			@;Contiene el valor 0
	mov r6,#0			@;Comprueba cuando empieza un bloque
	mov r8,#0			@;Numero de franjas a pintar
	mov r9,#0			@;Booleano (codigo o datos)
.Lperfranja:
	ldrb r5,[r1,r2]
	 
	cmp r5,r0
	bne .Lnofranja		@;Si no es franja del zocalo
	cmp r6,#0
	bne .Lnoprimera     @;Si no es la primera franja del bloque
	add r6,#1
	mov r7,r2
.Lnoprimera:
	add r8,#1
	strb r4,[r1,r2]
	b .Lnoencontrado
.Lnofranja:
	cmp r6,#0
	beq .Lnoencontrado	@;Si todavia no hemos encontrado la primera franja del bloque
	mov r6,#0
	push {r0-r3}
	mov r0,#0
	mov r1,r7
	mov r2,r8
	cmp r9,#0
	mov r3,#1
	bne .Ldatos		@;Si r9 no es 0, es un segmento de datos, ya que no es el primero
	mov r3,#0
	add r9,#1
.Ldatos:
	bl _gm_pintarFranjas
	mov r8,#0
	pop {r0-r3}
.Lnoencontrado:
	add r2,#1
	cmp r2,r3
	blt .Lperfranja
	pop {r1-r9,pc}

	

	.global _gm_pintarFranjas
	@; Rutina para para pintar las franjas verticales correspondientes a un
	@; conjunto de franjas consecutivas de memoria asignadas a un segmento
	@; (de código o datos) del zócalo indicado por parámetro.
	@;Parámetros:
	@;	R0: el número de zócalo que reserva la memoria (0 para borrar)
	@;	R1: el índice inicial de las franjas
	@;	R2: el número de franjas a pintar
	@;	R3: el tipo de segmento reservado (0 -> código, 1 -> datos)
_gm_pintarFranjas:
	push {r0-r8, lr}
	
	ldr r4, =0x06200000		@; Principio del mapa de baldosas
	add r4, #0x0000C000		@; La primera baldosa  
	add r4, #16				@; Saltarse las dos primeras filas sumando 16

	ldr r5, =_gs_colZoc		@; Posicion del vector de colores
	ldrb r5, [r5, r0]		@; Usar el zocalo como indice para poder cargar el color
	
.LNextBaldosa:
	cmp r1, #8
	blo .LbaldosaOk			@; Comprobar que se esta en la baldosa que toca
		sub r1, #8			@; Restar el numero de franjas que tiene una baldosa
		add r4, #64			@; Ir a la siguiente baldosa
		b .LNextBaldosa
.LbaldosaOk:
	add r4, r1				@; Ir a la siguiente franja dentro de la baldosa

.LPintar1:		
	tst r1, #1			@;Mirem si estem a una franja parell o imparell
	beq .LPar
	@; Franja impar
	ldrh r7, [r4]		@; Valor de la franja a pintar
	and r7, #0xFF		@; Quedarse bits bajos y cambiar el resto(altos)
	lsl r8, r5, #8		@; Desplazar el pixel
	add r7, r5, r8
	b .LpintarFranja

.LPar:
	ldrh r7, [r4]
	and r7, #0xFF00
	add r7, r5

.LpintarFranja:
	cmp r3, #0				@; Mirar si es segmento de codigo o datos
	bne .LAjedrez
						@; Pintar toda la franja si el segmneto es de codigo
	strh r7, [r4]		@; Pintar los 4 pixeles de la franja
	strh r7, [r4, #8]
	strh r7, [r4, #16]
	strh r7, [r4, #24]	@; Ir de 8 en 8 para ir de fila en fila
	b .LFranjaNext
			
.LAjedrez:
	tst r1, #1
	bne .LNuevoPatronAjedrez
	strh r7, [r4]		@; Pintar pixel 1 y 3 para hacer el efecto de ajedrez
	strh r7, [r4, #16]
	b .LFranjaNext
		
.LNuevoPatronAjedrez:
	strh r7, [r4, #8]	@; Pintar el pixel 2 y 4 para hacer el otro efecto de ajedrez
	strh r7, [r4, #24]

.LFranjaNext:
	add r1, #1			@; Saber la franja dentro de la baldosa sumando 1
	cmp r1, #8			@; Comprobar que es el final de la baldosa
	add r4, #1			@; Adelantar una franja
	moveq r1, #0		@; Mover a 0 el indice si es nueva baldosa
	addeq r4, #56		@; Sumar 56 para poder pasar a la baldosa siguiente por que es el ultimo pixel de la fila
	sub r2, #1			@; Numero de franjas --;
	cmp r2, #0			@; Mirar que se haya pintado todas las franjas
	bhi	.LPintar1
	
	pop {r0-r8,pc}


	.global _gm_rsiTIMER1
	@; Rutina de Servicio de Interrupción (RSI) para actualizar la representa-
	@; ción de la pila y el estado de los procesos activos.
_gm_rsiTIMER1:
	push {r0-r12,lr}
	mov r0,#0x6200000
	ldr r1,=0x12e
	add r0,r1
	ldr r1,=_gd_pcbs
	ldr r2,=_gd_stacks
	ldr r3,=0xB003D00
	mov r4,#0
	mov r12,#119
	
.LporProceso:
	mov r11,#0
	cmp r4,#0
	beq .LSO
	mov r5,#24
	mul r5,r4
	ldr r6,[r1,r5]				@;Miramos si PID activo
	cmp r6,#0
	sub r7,r12,#119
	sub r8,r12,#119
	beq .LCambiarBald
	add r5,#8
	ldr r6,[r1,r5]				@;R6= SP
	add r5,r2,r4,lsl#9
	sub r5,r6
.LnConfig:
	cmp r5,#32
	blt .LPonerBald
	sub r5,#32
	add r11,#1
	b .LnConfig


.LSO:
	mov r5,#24
	mul r5,r4
	add r5,#8
	ldr r6,[r1,r5]				@;R6= SP
	cmp r6,#0
	sub r7,r12,#119
	sub r8,r12,#119
	beq .LCambiarBald
	sub r5,r3,r6
.LnConfigSO:
	cmp r5,#61
	blt .LPonerBald
	sub r5,#61
	add r11,#1
	b .LnConfigSO
	
.LPonerBald:	
	cmp r11,#8
	bge .LCompleta
	add r7,r12,r11
	mov r8,r12
	b .LCambiarBald
.LCompleta:
	sub r11,#8
	add r7,r12,#8
	add r8,r12,r11
.LCambiarBald:
	strh r7,[r0]
	add r0,#2
	strh r8,[r0]
	add r0,#4
	mov r11,#0
	strh r11,[r0]
	add r0,#58
	add r4,#1
	cmp r4,#16
	blt .LporProceso
	
	@;AQUI EMPIEZA REPRESENTACION DE ESTADO
	mov r0,#0x6200000
	ldr r1,=0x134
	add r0,r1 
	mov r1,#178			@; R azul
	ldr r2,=_gd_pidz
	ldr r2,[r2]
	and r2,#0xF			@;Nos quedamos con zocalo de proceso RUN
	mov r2,r2,lsl#6
	strh r1,[r0,r2]
	@;Miramos cola de ready
	mov r1,#57			@; Y blanca
	ldr r2,=_gd_qReady
	ldr r3,=_gd_nReady
	ldr r3,[r3]
	mov r4,#0
.LPerProcRdy:
	cmp r3,#0
	beq .LfinRdy
	ldrb r5,[r2,r4]
	mov r5,r5,lsl#6
	strh r1,[r0,r5]
	add r4,#1
	sub r3,#1
	b .LPerProcRdy
.LfinRdy:
	mov r1,#34			@; B blanca
	ldr r2,=_gd_qDelay
	ldr r3,=_gd_nDelay
	ldr r3,[r3]
	mov r4,#0
.LPerProcDly:
	cmp r3,#0
	beq .LfinDly
	ldr r5,[r2,r4,lsl#2]
	and r5,#0xFF000000
	mov r5,r5,lsr#18
	strh r1,[r0,r5]
	add r4,#1
	sub r3,#1
	b .LPerProcDly
.LfinDly:
	
	pop {r0-r12,pc}
@;------------------------------------
.end

