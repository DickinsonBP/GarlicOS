@;==============================================================================
@;
@;	"garlic_itcm_proc.s":	código de las funciones de control de procesos (1.0)
@;						(ver "garlic_system.h" para descripción de funciones)
@;
@;==============================================================================

.section .itcm,"ax",%progbits

	.arm
	.align 2
	
	.global _gp_WaitForVBlank
	@; rutina para pausar el procesador mientras no se produzca una interrupción
	@; de retrazado vertical (VBL); es un sustituto de la "swi #5", que evita
	@; la necesidad de cambiar a modo supervisor en los procesos GARLIC
_gp_WaitForVBlank:
	push {r0-r1, lr}
	ldr r0, =__irq_flags
.Lwait_espera:
	mcr p15, 0, lr, c7, c0, 4	@; HALT (suspender hasta nueva interrupción)
	ldr r1, [r0]			@; R1 = [__irq_flags]
	tst r1, #1				@; comprobar flag IRQ_VBL
	beq .Lwait_espera		@; repetir bucle mientras no exista IRQ_VBL
	bic r1, #1
	str r1, [r0]			@; poner a cero el flag IRQ_VBL
	pop {r0-r1, pc}


	.global _gp_IntrMain
	@; Manejador principal de interrupciones del sistema Garlic
_gp_IntrMain:
	mov	r12, #0x4000000
	add	r12, r12, #0x208	@; R12 = base registros de control de interrupciones	
	ldr	r2, [r12, #0x08]	@; R2 = REG_IE (máscara de bits con int. permitidas)
	ldr	r1, [r12, #0x0C]	@; R1 = REG_IF (máscara de bits con int. activas)
	and r1, r1, r2			@; filtrar int. activas con int. permitidas
	ldr	r2, =irqTable
.Lintr_find:				@; buscar manejadores de interrupciones específicos
	ldr r0, [r2, #4]		@; R0 = máscara de int. del manejador indexado
	cmp	r0, #0				@; si máscara = cero, fin de vector de manejadores
	beq	.Lintr_setflags		@; (abandonar bucle de búsqueda de manejador)
	ands r0, r0, r1			@; determinar si el manejador indexado atiende a una
	beq	.Lintr_cont1		@; de las interrupciones activas
	ldr	r3, [r2]			@; R3 = dirección de salto del manejador indexado
	cmp	r3, #0
	beq	.Lintr_ret			@; abandonar si dirección = 0
	mov r2, lr				@; guardar dirección de retorno
	blx	r3					@; invocar el manejador indexado
	mov lr, r2				@; recuperar dirección de retorno
	b .Lintr_ret			@; salir del bucle de búsqueda
.Lintr_cont1:	
	add	r2, r2, #8			@; pasar al siguiente índice del vector de
	b	.Lintr_find			@; manejadores de interrupciones específicas
.Lintr_ret:
	mov r1, r0				@; indica qué interrupción se ha servido
.Lintr_setflags:
	str	r1, [r12, #0x0C]	@; REG_IF = R1 (comunica interrupción servida)
	ldr	r0, =__irq_flags	@; R0 = dirección flags IRQ para gestión IntrWait
	ldr	r3, [r0]
	orr	r3, r3, r1			@; activar el flag correspondiente a la interrupción
	str	r3, [r0]			@; servida (todas si no se ha encontrado el maneja-
							@; dor correspondiente)
	mov	pc,lr				@; retornar al gestor de la excepción IRQ de la BIOS


	.global _gp_rsiVBL
	@; Manejador de interrupciones VBL (Vertical BLank) de Garlic:
	@; se encarga de actualizar los tics, intercambiar procesos, etc.
_gp_rsiVBL:
	push {r4-r7, lr}
	
	ldr r4, =_gd_tickCount	@; guardar en r4 la @ de _gd_tickCount 
	ldr r5, [r4]			@; guardar el valor de _gd_tickCoutn en r5
	add r5, #1				@; incrementar variable _gd_tickCount
	str r5, [r4]			@; guardar nuevo valor de _gd_tickCount

	ldr r4, =_gd_qReady		@; dirección inicial de la cola de RDY
	ldrb r5, [r4]			@; zócalo del primer proceso en la cola de RDY
	ldr r6, =_gd_pcbs		@; dir del vector depcbs
	mov r4, #24
	mla r4, r5, r4, r6		@; dirección base del proceso en el PCB
	ldr r5, [r4, #20]		
	add r5, #1				@; aumentar el WorkTicks
	str r5, [r4, #20]		@; guardar WorkTicks
	ldr r4, =_gd_nReady		@; detectar si existe algún proceso pendiente en la cola de ready (_gd_nReady == 0)
	ldr r5, [r4]
	cmp r5, #0				
	beq .Lfi_rsiVBL			@; si no hay procesos la RSI finaliza sin cambio de contexto
	
	ldr r6, =_gd_pidz		@; si el proceso actual a desbancar es del SO (_gd_pidz == 0), salvar contexto del proceso 
	ldr r7, [r6]
	cmp r7, #0				@; si el valor de _gd_pidz (combinación entr PID y zócalo) es 0 quiere decir que es del SO
	beq .Lsalvar_contexto

	mov r7, r7, lsr #4		@; si el proceso a desbancar no es del SO pero el PID es 0, es decir, un proceso de programa que ha acabado
	cmp r7, #0				@; su ejecucion (pid == 0 y z != 0) no hay que salvar el contexto y restaurar el siguiente proceso de la cola de RDY
	beq .Lrestaurar_contexto
	
.Lsalvar_contexto:			@; salvamos el contexto del proceso actual
	bl _gp_salvarProc		@; llamada a _gp_salvarProc
	
.Lrestaurar_contexto:		@; restauramos el proceso del siguiente proceso de la cola de Ready
	bl _gp_restaurarProc	@; llamada a _gp_restaurarProc
	
.Lfi_rsiVBL:
	bl _gp_actualizarDelay	@; llamada a _gp_actualizarDelay
	
	pop {r4-r7, pc}


	@; Rutina para salvar el estado del proceso interrumpido en la entrada
	@; correspondiente del vector _gd_pcbs
	@;Parámetros
	@; R4: dirección _gd_nReady
	@; R5: número de procesos en READY
	@; R6: dirección _gd_pidz
	@;Resultado
	@; R5: nuevo número de procesos en READY (+1)
_gp_salvarProc:
	push {r8-r11, lr}
	
	ldr r8, [r6]			@; cargar en r8 valor de _gd_pidz
	tst r8, #0x80000000		@; si el bit de más peso está a 1 no se guradará en la cola de RDY
	and r8, r8, #0xf		@; realizamos una máscara para obtener el número de zócalo que se encuentran en los 4 bits bajos, 15=1111
	bne .Lno_poner_enQRDY
	ldr r9, =_gd_qReady		@; cargar @ de _gd_qReady
	strb r8, [r9, r5]		@; guardar número de zócalo en la última posición de la cola de RDY
	add r5, #1				@; incrementar contador de procesos pendientes
	str r5, [r4]			@; actualizar _gd_nReady
.Lno_poner_enQRDY:
	ldr r9, =_gd_pcbs		@; dirección del vector de pcbs
	mov r10, #24			@; tamaño del pcb
	mla r11, r8, r10, r9	@; 24 * z + @ _gd_pcbs = _gd_pcbs[z]
	
	ldr r8, [sp, #60]		@; guardar en r8 valor de r15(LR) = SP_irq + 60
	str r8, [r11, #4]		@; guardar valor de r15 en el campo PC de _gd_pcbs[z]
	
	mrs r9, SPSR			@; guardar en r9 el estado del proceso a desbancar es el SPSR ya que el CPSR es el de la interrupción
	str r9, [r11, #12]		@; guardar el estado en el campo Status de _gd_pcbs[z]
	
	mov r8, sp
	
	mrs r10, CPSR			@; cogemos el modo de ejecución actual
	orr r10, #0x1F			@; le hacemos una máscara para obtener el valor del modo system
	msr CPSR, r10			@; guardamos en el CPSR con el nuevo modo, System
	
	@; apilamos los regs r0-r12 y r14 en la pila del proceso a desbancar cogiendo estos valores de la pila del irq
	
	ldr r11, [r8, #56]		@; r12
	ldr r10, [r8, #12]		@; r11
	ldr r9, [r8, #8]		@; r10
	push {r9-r11, lr}
	
	ldr r11, [r8, #4]		@; r9
	ldr r10, [r8]			@; r8
	ldr r9, [r8, #32]		@; r7
	push {r9-r11}
	
	ldr r11, [r8, #28]		@; r6
	ldr r10, [r8, #24]		@; r5
	ldr r9, [r8, #20]		@; r4
	push {r9-r11}
	
	ldr r11, [r8, #52]		@; r3
	ldr r10, [r8, #48]		@; r2
	ldr r9, [r8, #44]		@; r1
	push {r9-r11}
	
	ldr r9, [r8, #40]		@; r0
	push {r9}
	
	ldr r8, [r6]			@; cargamos el valor de la variable _gd_pidz.
	and r9, r8, #0xF		@; filtramos los 28 bits correspondientes al pid de proceso
	mov r10, #24			@; tamaño del pcb							 					
	ldr r11, =_gd_pcbs		@; cargamos la @ del vector de pcbs.
	mla r10, r9, r10, r11	@; 24 * z + @ _gd_pcbs = _gd_pcbs[z]
	str sp, [r10, #8]		@; guardamos el valor del r13 = SP en en el campo SP del _gd_pcbs[z]
	
	mrs r10, CPSR			@; guardar en r10 el CPSR 
	bic r10, #0x0D			@; le hacemos un bic para quedarnos con el valor 0x12 (0D = 0000 1101)
	msr CPSR, r10			@; guardar el nuevo CPSR

	pop {r8-r11, pc}


	@; Rutina para restaurar el estado del siguiente proceso en la cola de READY
	@;Parámetros
	@; R4: dirección _gd_nReady
	@; R5: número de procesos en READY
	@; R6: dirección _gd_pidz
_gp_restaurarProc:
	push {r8-r11, lr}
	
	sub r5, #1						@; procesos en la cola de RDY -1
	str r5, [r4]					@; guardar nuevo valor en la @ _gd_nReady
	
	ldr r9, =_gd_qReady				@; cargar @ de _gd_qReady
	ldrb r8, [r9]					@; coger número de zócalo del primer proceso de la cola de RDY
	
.LrecolocarRDY:
	ldrb r10, [r9, #1]				@; cargar zócalo 
	strb r10, [r9]					@; y guardarlo en la posición anterior
	add r9, #1						@; siguiente posición
	subs r5, #1						
	bhi .LrecolocarRDY				@; comprobamos si ya se han desplazado todos los procs
	
	mov r9, #24						@; tamaño del pcb
	ldr r10, =_gd_pcbs				@; dirección del vector de pcbs
	mla r9, r8, r9, r10				@; 24 * z + @ _gd_pcbs = _gd_pcbs[z] 
	ldr r10, [r9]					@; guardamos en r8 el valor del PID (primera posición del _gd_pcbs[z])
	orr r8, r10, lsl #4				@; los 28 bits altos corresponden al pid y los 4 bits bajos al zócalo, por lo que la lsl desplaza el pid 4bits a la izquierda y se le hace una or de los bits del zócalo
	str r8, [r6]					@; guardamos en _gd_pidz
	
	ldr r10, [r9, #4]				@; recuperamos el valor del PC del proceso a restaurar _gd_pcbs[z]			
	str r10, [sp, #60]				@; guardamos este PC en SP_irq+60 = LR (ret. Proc)
	
	ldr r10, [r9, #12]				@; el estado del proceso a restaurar _gd_pcbs[z] del campo Status
	msr SPSR, r10					@; guardamos en el SPSR el estado del proceso a restaurar
	
	mov r8, sp						@; guardamos el SP_irq para copiar los registros posteriormente en la pila del modo irq
	
	mrs r10, CPSR					@; guardamos en r9 el CPSR
	orr r10, #0x1F					@; cambiar a modo System 1F
	msr CPSR, r10					@; guardar el nuevo modo
	
	ldr sp, [r9, #8]				@; recuperar el valor de r13(sp) en el _gs_pcbs[z] del campo SP
	
	pop {r9-r11}					@; desapilaremos del valor de r0-r12 y r14 y los copiaremos en la pila del modo IRQ
	str r9, [r8, #40]				@; r0
	str r10, [r8, #44]				@; r1
	str r11, [r8, #48]				@; r2
	
	pop {r9-r11}					
	str r9, [r8, #52]				@; r3
	str r10, [r8, #20]				@; r4
	str r11, [r8, #24]				@; r5
	
	pop {r9-r11}					
	str r9, [r8, #28]				@; r6
	str r10, [r8, #32]				@; r7
	str r11, [r8]					@; r8
	
	pop {r9-r11}					
	str r9, [r8, #4]				@; r9
	str r10, [r8, #8]				@; r10
	str r11, [r8, #12]				@; r11
	
	pop {r9, lr}					
	str r9, [r8, #56]				@; r12
	
	mrs r10, CPSR					@; guardar en r10 el CPSR
	bic r10, #0x0D					@; le hacemos un bic para quedarnos con el valor 0x12 (0D = 0000 1101)
	msr CPSR, r10					@; guardar el nuevo CPSR
	
	pop {r8-r11, pc}


	.global _gp_crearProc
	@; prepara un proceso para ser ejecutado, creando su entorno de ejecución y
	@; colocándolo en la cola de READY
	@;Parámetros
	@; R0: intFunc funcion,
	@; R1: int zocalo,
	@; R2: char *nombre
	@; R3: int arg
	@;Resultado
	@; R0: 0 si no hay problema, >0 si no se puede crear el proceso
_gp_crearProc:
	push {r1-r9, lr}
	
	cmp r1, #0				@; comprobar si zócalo=0
	moveq r0, #1			@; si es 0, no se puede crear porque está reservado para el SO
	beq .LfincrearProc		@; devolvemos >0 por r0 para indicar que no se ha podido crear el proceso
	mov r4, #24				@; tamaño pcb
	ldr r5, =_gd_pcbs		@; @ de _gd_pcbs (vector de pcbs)
	mla r4, r1, r4, r5 		@; multiplicamos 24 * z + @ de _gd_pcbs para acceder a la posición pcbs[z]
	ldr r6, [r4]			@; cargamos el valor del pid de z (desplazamiento 0)
	cmp r6, #0				@; si pid=0, el zócalo está libre y podemos crear el proceso
	movne r0, #1			@; sino es que está ocupado devolvemos >0 por r0 para indicar que no se ha podido crear el proceso
	bne .LfincrearProc
	
	ldr r6, =_gd_pidCount	@; @ de _gd_pidCount
	ldr r7, [r6]			@; guardamos el valor de _gd_pidCount = contador de PIDs
	add r7, #1				@; le sumamos 1 para el nuevo PID del nuevo proceso
	str r7, [r4]			@; guardamos el nuevo PID (r7) en el campo PID del _gd_pcbs[z] (r4)
	str r7, [r6]			@; finalmente actualizamos la variable gloabal _gd_pidCount (r6) con el nuevo valor (r7)
	
	add r0, #4				@; le sumamos 4  para compensar el decremento que sufrirá la primera vez que se restaure el proceso
	str r0, [r4, #4]		@; guardar dirección de la rutina inicial del proceso en el campo PC del _gd_pcbs[z]
	
	ldr r6, [r2]			@; cargar el valor del puntero char (nombre)
	str r6, [r4, #16]		@; guardar los 4 carácteres del nombre en clave del programa en el campo keyName del _gd_pcbs[z]
	
	ldr r6, =_gd_stacks 	@; para calcular la dir base de la pila del proceso, accedemos al _gd_stacks que contiene las 15 pilas
	add r6, r6, r1, lsl #9	@; tenemos que cada pila ocupa 512 bytes, 512 * z + @_gd_stacks ahora en r6 tendremos el top de la pila de z+1	
	sub r6, #4				@; al restarle 4 (ya que son 128 posiciones de 4B cada una) en r6 tendremos la dir base de la pila (r14)
	
	ldr r8, =_gp_terminarProc
	str r8, [r6]			@; guardamos en r14 la dirección de _gp_terminarProc()
	mov r9, #0				@; contador del bucle
	mov r8, #0				@; 0 para guardar en los registros r1-r12
.LinicializarPila:
	sub r6, #4				@; para la siguiente posición de la pila se resta 4 ya que es lo que ocupa un word (4B)
	str r8, [r6]			@; reg = 0
	add r9, #1				@; aumentamos ocntador
	cmp r9, #12				@; comprobar si ya estan los 12 registros a 0
	blt .LinicializarPila	@; sino continuar en el bucle
	sub r6, #4				@; una posición menos en la pila para inicializar r0
	str r3, [r6]			@; r0= arg (cuarto parámetro)

	str r6, [r4, #8]		@; guardar como r13(sp) r6 porque tendremos el top de la pila y lo guardamos en el campo SP en el _gd_pcbs[z] 
	
	mov r6, #0x1F			@; guardar el valor del modo system 
	str r6, [r4, #12]		@; guardar en el campo Status del _gd_pcbs[z] para que la ejecución sea en modo system
	
	str r8, [r4, #20]		@; guardar a 0 el contador de ticks inicial en el campo workTics del _gd_pcbs[z]
	
	ldr r6, =_gd_qReady		@; cargar @ de _gd_qReady = cola de RDY
	ldr r7, =_gd_nReady		@; guardar dirección de _gd_nReady
	bl _gp_inhibirIRQs
	ldr r8, [r7]			@; coger valor de _gd_nReady = num procesos en RDY
	strb r1, [r6, r8]		@; guardar el numero de zócalo (r1) en la última posición (r8) de la cola de RDY(r6)
	add r8, #1				@; actualizar numero de procesos en la cola de pendientes 
	str r8, [r7]			@; guardar en la variable global _gd_nReady
	bl _gp_desinhibirIRQs
	
	mov r0, #0				@; devolvemos 0 indicando que el proceso se ha podido crear
	
.LfincrearProc:

	pop {r1-r9, pc}
	

	@; Rutina para terminar un proceso de usuario:
	@; pone a 0 el campo PID del PCB del zócalo actual, para indicar que esa
	@; entrada del vector _gd_pcbs está libre; también pone a 0 el PID de la
	@; variable _gd_pidz (sin modificar el número de zócalo), para que el código
	@; de multiplexación de procesos no salve el estado del proceso terminado.
_gp_terminarProc:
	ldr r0, =_gd_pidz
	ldr r1, [r0]			@; R1 = valor actual de PID + zócalo
	and r1, r1, #0xf		@; R1 = zócalo del proceso desbancado
	bl _gp_inhibirIRQs
	str r1, [r0]			@; guardar zócalo con PID = 0, para no salvar estado			
	ldr r2, =_gd_pcbs
	mov r10, #24
	mul r11, r1, r10
	add r2, r11				@; R2 = dirección base _gd_pcbs[zocalo]
	mov r3, #0
	str r3, [r2]			@; pone a 0 el campo PID del PCB del proceso
	str r3, [r2, #20]		@; borrar porcentaje de USO de la CPU
	ldr r0, =_gd_sincMain
	ldr r2, [r0]			@; R2 = valor actual de la variable de sincronismo
	mov r3, #1
	mov r3, r3, lsl r1		@; R3 = máscara con bit correspondiente al zócalo
	orr r2, r3
	str r2, [r0]			@; actualizar variable de sincronismo
	bl _gp_desinhibirIRQs
.LterminarProc_inf:
	bl _gp_WaitForVBlank	@; pausar procesador
	b .LterminarProc_inf	@; hasta asegurar el cambio de contexto
	
	
	@; Rutina para actualizar la cola de procesos retardados, poniendo en
	@; cola de READY aquellos cuyo número de tics de retardo sea 0
_gp_actualizarDelay:
	push {r0-r7, lr}
	
	ldr r0, =_gd_nDelay
	ldr r1, [r0]
	cmp r1, #0				@; comproabr que hay procesos en la cola de retraso
	beq .Lfin_actualizarDelay
	ldr r3, =_gd_qDelay	
	mov r2, r1				@; variable de control para bucle de decrementar tics
.Lmodificar_tics:	
	ldr r4, [r3]			@; posición en la cola de retardo
	sub r4, #1				@; restar 1 a los tics
	movs r5, r4, lsl #8		@; eliminar zócalo y actualizar los flags para comprobar si los tics han llegado a 0
	beq .Lponer_enRDY		@; si es 0 hay que poner el proceso en la cola de RDY
	str r4, [r3]
	add r3, #4				@; siguiente posición en la cola de retardo
.Lsig_proc:
	subs r2, #1				@; un proc menos a comprobar
	bhi .Lmodificar_tics	@; si hay más mirar el siguiente proc sino terminar
	beq .Lfin_actualizarDelay
.Lponer_enRDY:
	ldr r5, =_gd_nReady
	ldr r6, =_gd_qReady
	ldr r7, [r5]
	mov r4, r4, lsr #24		@; obtener número de zócalo
	strb r4, [r6, r7]		@; guardar zócalo en última posición de la cola de RDY
	add r7, #1				@; incrementar num de procs en RDY
	str r7, [r5]			@; guardar nuevo num de procs en RDY
	
	push {r2, r3}			@; se hace push del valor de la posición en la cola de RDY y del num de procesos sin comproabr para luego continuar con estos valores
.Ldesplazar_qDelay:
	ldr r4, [r3, #4]		@; coger proc siguiente y guardarlo en la posición del proc actual (el que se ha pasado a RDY) y así hasta el último proc en la cola
	str r4, [r3]
	add r3, #4
	subs r2, #1
	bhi .Ldesplazar_qDelay
	pop {r2, r3}
	sub r1, #1				@; actualizar numero de procesos en la cola de Delay
	str r1, [r0]
	b .Lsig_proc
	
.Lfin_actualizarDelay:

	pop {r0-r7, pc}
	
.global _gp_numProc
	@;Resultado
	@; R0: número de procesos total
_gp_numProc:
	push {r1-r2, lr}
	
	mov r0, #1				@; contar siempre 1 proceso en RUN
	ldr r1, =_gd_nReady
	ldr r2, [r1]			@; R2 = número de procesos en cola de READY
	add r0, r2				@; añadir procesos en READY
	ldr r1, =_gd_nDelay
	ldr r2, [r1]			@; R2 = número de procesos en cola de DELAY
	add r0, r2				@; añadir procesos retardados
	
	pop {r1-r2, pc}
	
	.global _gp_matarProc
	@; Rutina para destruir un proceso de usuario:
	@; borra el PID del PCB del zócalo referenciado por parámetro, para indicar
	@; que esa entrada del vector _gd_pcbs está libre; elimina el índice de
	@; zócalo de la cola de READY o de la cola de DELAY, esté donde esté;
	@; Parámetros:
	@;	R0:	zócalo del proceso a matar (entre 1 y 15).
_gp_matarProc:
	push {r0-r6, lr} 

	ldr r1, =_gd_pcbs		@; dir base del vector de pcbs
	mov r2, #24
	mla r1, r2, r0, r1		@; desplazamiento dentro del vector de pcbs para acceder a _gd_pcbs[z]
	mov r2, #0
	bl _gp_inhibirIRQs
	str r2, [r1]			@; poner a 0 el campo PID de _gd_pcbs[z] para permitir cargar otro proceso en ese mismo zócalo
	
	ldr r1, =_gd_qReady		@; dir base de la cola de RDY
	ldr r2, =_gd_nReady		
	ldr r3, [r2]			@; num de procesos en RDY
	mov r4, #0				@; contador de cola de RDY
.LbuscarEnRDY:
	cmp r4, r3			
	beq .LMirarEnDLY		@; si no encontramos el proceso en la cola de RDY buscamos en la de Delay
	ldrb r6, [r1]			
	cmp r0, r6				@; comprobar si el zócalo es el del proceso que buscamos
	beq .LdesplazarColaRDY	@; si lo es lo quitamos de la cola de Ready
	add r1, #1				@; sinó miramos el siguiente
	add r4, #1
	b .LbuscarEnRDY

.LMirarEnDLY:
	ldr r1, =_gd_qDelay		@; dir base de la cola de Delay
	ldr r2, =_gd_nDelay
	ldr r3, [r2]			@; num de procesos en Delay
	mov r4, #0				@; contador de cola de Delay
.LbuscarEnDLY:
	cmp r4, r3
	beq .LfinMatar			@; si tampoco esta en la de Delay, salir
	ldr r6, [r1]			@; zocalo + tics
	mov r6, r6, lsr #24		@; cogemos solo el zocalo
	cmp r6, r0				@; comprobar si el zócalo es el del proceso que buscamos
	beq .LdesplazarColaDLY	@; si lo es lo quitamos de la cola de Delay
	add r1, #4				@; sinó miramos el siguiente
	add r4, #1
	b .LbuscarEnDLY
	
.LdesplazarColaRDY:
	ldrb r5, [r1, #1]		@; desplazamos la cola de en la que se encuentra según el desplazamiento		
	strb r5, [r1]			@; guardar en nueva posición
	add r1, #1				@; sumar al vector el desplazamiento
	add r4, #1
	cmp r4, r3				@; si la cola no ha terminado, desplazar siguiente poceso
	blo .LdesplazarColaRDY
	sub r3, #1				
	str r3, [r2]			@; decrementamos el numero de procesos en la cola de RDY o Delay
	b .LfinMatar
.LdesplazarColaDLY:
	ldr r5, [r1, #4]		@; desplazamos la cola de en la que se encuentra según el desplazamiento		
	str r5, [r1]			@; guardar en nueva posición
	add r1, #4				@; sumar al vector el desplazamiento
	add r4, #1
	cmp r4, r3				@; si la cola no ha terminado, desplazar siguiente poceso
	blo .LdesplazarColaDLY
	sub r3, #1				
	str r3, [r2]			@; decrementamos el numero de procesos en la cola de RDY o Delay
	
.LfinMatar:
	bl _gp_desinhibirIRQs
	
	pop {r0-r6, pc}

	
	.global _gp_retardarProc
	@; retarda la ejecución de un proceso durante cierto número de segundos,
	@; colocándolo en la cola de DELAY
	@;Parámetros
	@; R0: int nsec
_gp_retardarProc:
	push {r0-r3, lr}
	
	ldr r1, [r3]			@; @ de pidz
	orr r1, #0x80000000		@; poner a 1 el bit de más peso de _gd_pidz para que no lo ponga en la cola de Ready salvar_proceso
	str r1, [r3]
	mov r1, #60				@; se producen 60 retrocesos verticales en un segundo
	mul r0, r1, r0			@; r0 * 60 serán los tics que debe retardar el proceso
	
	orr r2, r0, r2, lsl #24	@; poner en los 8 bits altos el zócalo del proceso actual (_gd_pidz) + los 24 bajos de los tics
	ldr r0, =_gd_qDelay		@; @ de la cola de Delay
	ldr r1, =_gd_nDelay		@; @ de nDelay
	bl _gp_inhibirIRQs
	ldr r3, [r1]			@; numero de procesos en la cola de Delay
	str r2, [r0, r3, lsl #2]	@; guardar en la cola de Delay el proceso actual
	add r3, #1				@; aumentar num procesos en Delay
	str r3, [r1]			@; guardar nuevo num en gd_nDelay
	bl _gp_desinhibirIRQs

	bl _gp_WaitForVBlank	@; ceder la CPU invocando _gp_WaitForVBlank

	pop {r0-r3, pc}


	.global _gp_inihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 0, para inhibir todas
	@; las IRQs y evitar así posibles problemas debidos al cambio de contexto
_gp_inhibirIRQs:
	push {r0,r1, lr}
	
	ldr r0, =0x04000208		@; reg IME
	mov r1, #0
	strh r1, [r0]

	pop {r0,r1, pc}


	.global _gp_desinihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 1, para desinhibir todas
	@; las IRQs
_gp_desinhibirIRQs:
	push {r0,r1, lr}

	ldr r0, =0x04000208		@; reg IME
	mov r1, #1
	strh r1, [r0]
	
	pop {r0,r1, pc}


	.global _gp_rsiTIMER0
	@; Rutina de Servicio de Interrupción (RSI) para contabilizar los tics
	@; de trabajo de cada proceso: suma los tics de todos los procesos y calcula
	@; el porcentaje de uso de la CPU, que se guarda en los 8 bits altos de la
	@; entrada _gd_pcbs[z].workTicks de cada proceso (z) y, si el procesador
	@; gráfico secundario está correctamente configurado, se imprime en la
	@; columna correspondiente de la tabla de procesos.
_gp_rsiTIMER0:
	push {r0-r7, lr}

	ldr r0, =_gd_pcbs		@; dirección inicial vector de PCBs
	mov r1, #24				@; desplazamiento dentro del vector de PCBs
	mov r2, #20				@; desplazamiento dentro del PCBs para acceder al campo workTicks
	ldr r4, [r0, r2]		@; coger campo workTicks del PCB[0]
	mov r4, r4, lsl #8
	mov r5, r4, lsr #8		@; coger los 24 bits bajos que son los ciclos de trabajo
	mov r6, #16				@; procesos restantes en el PCB
.LsumarTicks:
	subs r6, #1
	beq .LcalcularPorcentaje
	add r0, r1				@; siguiente proceso a mirar
	ldr r3, [r0]
	cmp r3, #0				@; PID = 0 zócalo sin proceso
	beq .LsumarTicks
	ldr r4, [r0, r2]		@; coger campo workTicks del PCB[n]
	mov r4, r4, lsl #8		@; coger los 24 bits bajos que son los ciclos de trabajo
	add r5, r4, lsr #8		@; y sumarlos al total de ticks		
	b .LsumarTicks
.LcalcularPorcentaje:
	ldr r0, =_gd_pcbs		@; dirección inicial vector de PCBs
	mov r6, #0
.Lcalculo:
	ldr r4, [r0, r2]		@; coger campo workTicks del PCB[z]
	mov r4, r4, lsl #8		@; coger los 24 bits bajos que son los ciclos de trabajo
	mov r4, r4, lsr #8		@; poner a 0 
	push {r0-r3}
	mov r1, #100
	mov r0, r4				@; numerador -> ticks del proceso
	mul r0, r1
	mov r1, r5				@; denominador -> ticks totales
	ldr r2, =_gd_quo
	ldr r3, =_gd_mod
	bl _ga_divmod
	ldr r2, [r2]
	mov r7, r2, lsl #24		@; poner en los 8 bits altos el porcentaje y los 24 bajos a 0
	pop {r0-r3}
	str r7, [r0, #20]		@; guardar en _gd_pcbs[z]
	push {r0-r3}
	ldr r0, =_gd_numstr
	mov r1, #4
	mov r2, r7, lsr #24		@; vovler a mover los bits para imprimir por pantalla
	bl _gs_num2str_dec
	ldr r0, =_gd_numstr
	add r1, r6, #4			@; la fila es el zócalo + 4
	mov r2, #28
	mov r3, #0			@; el porcentaje de uso se imprimirá en blanco
	bl _gs_escribirStringSub
	pop {r0-r3}
.LmirarSig:
	add r0, r1				@; siguiente zócalo
	add r6, #1				@; contador ++
	cmp r6, #16				@; si hemos llegado al final salir de la RSI
	beq .LfinRSI_timer0
	ldr r4, [r0]
	cmp r4, #0
	beq .LmirarSig
	b .Lcalculo
.LfinRSI_timer0:
	ldr r0, =_gd_sincMain	@; sincronizar con el main para que sepa que puede escribir el %
	ldr r1, [r0]
	orr r1, #1
	str r1, [r0]
	
	pop {r0-r7, pc}
	
.end

