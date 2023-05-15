@;==============================================================================
@;
@;	"garlic_itcm_graf.s":	código de rutinas de soporte a la gestión de
@;							ventanas gráficas (versión 2.0)
@;
@;==============================================================================

NVENT	= 16				@; número de ventanas totales
PPART	= 4					@; número de ventanas horizontales o verticales
							@; (particiones de pantalla)
L2_PPART = 2				@; log base 2 de PPART

VCOLS	= 32				@; columnas y filas de cualquier ventana
VFILS	= 24
PCOLS	= VCOLS * PPART		@; número de columnas totales (en pantalla)
PFILS	= VFILS * PPART		@; número de filas totales (en pantalla)

WBUFS_LEN = 68				@; longitud de cada buffer de ventana (64+4)

.section .itcm,"ax",%progbits

	.arm
	.align 2


	.global _gg_escribirLinea
	@; Rutina para escribir toda una linea de caracteres almacenada en el
	@; buffer de la ventana especificada;
	@;Parámetros:
	@;	R0: ventana a actualizar (int v)
	@;	R1: fila actual (int f)
	@;	R2: número de caracteres a escribir (int n)
_gg_escribirLinea:
	push {r0-r8, lr}

	cmp r1, #VFILS			@;Si la fila actual al num de files total de finestra
	subeq r1, #1 			@;Restarem 1 a la fila actual, que sera la fila on haurem d'escriure
	bleq _gg_desplazar		@;En el cas que sigui final de finestra haurem de desplaçar una fila tot cap a d'alt
	
	ldr r4, =_gd_wbfs		@;Direcció dels buffers de finestra
	mov r5, #WBUFS_LEN
	mla r4, r0, r5, r4		@;Calcul de @ del buffer de finestra
	add r4, #4 				@;r4 = Adreça buffer finestra

	ldr r3 , =map2Pointer	@;Direcció del punter del fondo 2
	ldr r3 , [r3]
	lsr r5 , r0, #L2_PPART	@;r5 = num_finestra / PPART --> f0=0,f1=0,f2=1,f3=1
	and r6 , r0, #3	         @;r6 num columna mirarem els 2 bits baixos de la finestra pasada per parametre

	mov r7 , #PCOLS
	mul r8 ,r7 ,r5
	mov r7 , #VFILS
	mul r9 ,r8 ,r7
	mov r7 , #VCOLS
	mul r7 ,r6, r7 
	add r7, r9
	lsl r7 ,#1 			@;Adreça base mapa de baldoses per pantalla
						@;r7=((fila_finestra*PPART*VFILS*VCOLS) + (col_finestra*VCOLS))*2
						@;Serà multiplicat per 2 perque s'utilitzen halfword

	mov r5, #PCOLS*2
	mla r7 ,r5 ,r1 ,r7	
	add r7, r3          @r7= @ mapa baldoses amb la fila actual

	mov r1, #0 			@;punter buffer i mapa de baldoses
	mov r0, #2
	mul r2, r0 			@;r2 --> Num total de caracters que haurem d'escriure
	@;bucle per anar pasant l'informació del buffer al mapa
	.LBucle_informacio:
			cmp r1, r2
			beq .LfiBucle
			ldrh r3, [r4,r1]
			sub r3, #32
			strh r3, [r7,r1]
			add r1, #2
			b .LBucle_informacio
	.LfiBucle:

	pop {r0-r8, pc}


	.global _gg_desplazar
	@; Rutina para desplazar una posición hacia arriba todas las filas de la
	@; ventana (v), y borrar el contenido de la última fila
	@;Parámetros:
	@;	R0: ventana a desplazar (int v)
_gg_desplazar:
	push {r0-r9, lr}

	ldr r3 , =map2Pointer	@;Direcció del punter del fondo 2
	ldr r3 , [r3]
	lsr r5 , r0, #L2_PPART	@;r5 = num_finestra / PPART --> f0=0,f1=0,f2=1,f3=1
	and r6 , r0, #3	         @;r6 num columna mirarem els 2 bits baixos de la finestra pasada per parametre

	mov r7 , #PCOLS
	mul r8 ,r7 ,r5
	mov r7 , #VFILS
	mul r9 ,r8 ,r7
	mov r7 , #VCOLS
	mul r7 ,r6, r7 
	add r7, r9
	lsl r7 ,#1 				@;Adreça base mapa de baldoses per pantalla
							@;r7=((fila_finestra*PPART*VFILS*VCOLS) + (col_finestra*VCOLS))*2
							@;Serà multiplicat per 2 perque s'utilitzen halfword
	add r7, r3          	@r7= @ mapa baldoses amb el desplaçament de la pantalla calculat

	mov r0, #PCOLS
	lsl r0, #1    			@;r0 ens servirà per fer els calculs per agafar el desplaçamaent a l'inici de linea que vulguem
	mov r5, #VCOLS
	lsl r5, #1 				@;Maxim de columnes al mapa de baldoses

	mov r1, #0  			@;r1 = contador de la linea a desplaçar

	.LDesplaçamentLinea:
		cmp r1, #VFILS 		@;mirem si ja hem fet el desplaçament per totes les files
		beq .LFinal

		mla r2, r0,r1,r7 	@;Posició inicial de la fila actual(el seu inici serà de la fila 0)
		add r1, #1

		mla r3, r0,r1,r7 	@;r3=posi inicial fila a desplaçar a l'anterior
		sub r1, #1

		mov r4, #0 			@;contador per columnes fins arribar a VCOLS*2
		.LDesplaçamentValorAValor:

			cmp r4,r5
			beq .LseguentDesplaçament
			
			ldrh r6, [r3,r4] 	@;Carreguem el valor de la posició r4 de la fila per guardar-la a la fila anterior en la mateixa posició de col
			cmp r1, #VFILS-1 	@;Mirem que no estesem a la ultima fila, perque hauriem de buidar la ultima fila de la finestra
			moveq r6, #0

			strh r6, [r2,r4]	@;guardem el valor a la fila anterior
			add r4, #2 			@;contador +2 per mirar el seguent valor de col
			b .LDesplaçamentValorAValor
		.LseguentDesplaçament:

		add r1, #1 				@;+1 al contador de files a desplaçar
		b .LDesplaçamentLinea

	.LFinal:

	pop {r0-r9, pc}


	.global _gg_escribirLineaTabla
	@; escribe los campos básicos de una linea de la tabla correspondiente al
	@; zócalo indicado por parámetro con el color especificado; los campos
	@; son: número de zócalo, PID, keyName y dirección inicial
	@;Parámetros:
	@;	R0 (z)		->	número de zócalo
	@;	R1 (color)	->	número de color (de 0 a 3)
_gg_escribirLineaTabla:
	push {r0-r10,lr}

		@;Carrega dir mem inicial pcb Zocalo corresponent
		ldr r3, =_gd_pcbs
		mov r4 ,#24 			@;Desplaçament a r4 dels parametres del pcb (6 parametres * 4 size de cada un)
		mla r3, r4, r0, r3 		@; r3 serà la dir mem inicial del pcb del zocalo demanat

		@;Carrega dir mem inicial taula Zocalo corresponent
		mov r2, #0x06200000 	@;r2--> dir mem inicial pantalla inferior
		add r2, #VCOLS*2*4 		@;li sumarem el desplaçament per situar-nos a l'inici de la informació del zocalo 0, 32 columnes * 2(halfword)*4 files
		mov r4, r0, lsl #6 		@;r4 --> Desplaçament a la fila de la taula del zocalo demanat (num zocalo * 64) 64 es VCOLS*2
		add r2, r4 				@;Inici de la linea taula del zocalo demanat

		@;Dibuixar simbols separadors amb el color corresponent
		mov r4, #104 		@;Valor del simbol separador per a la baldosa
		mov r10, r1
		mov r8, r1, lsl #7 	@;Color corresponent
		add r4, r8 			@;Simbol separador amb el color aplicat

		strh r4, [r2] 		@;1er separador
		mov r5, #6 			@;Desplaçament entre separadors
		strh r4, [r2,r5] 	@;2n separador
		add r5, #10 
		strh r4, [r2,r5] 	@;3er separador
		add r5, #10
		strh r4, [r2,r5] 	@;4rt separador
		add r5, #18
		strh r4, [r2,r5] 	@;5e separador
		add r5, #6
		strh r4, [r2,r5] 	@;6e separador
		add r5, #4
		strh r4, [r2,r5] 	@;7e separador
		add r5, #8
		strh r4, [r2,r5] 	@;8e separador

		@;Guardarem variables importants en altres registres

		mov r5, r10 		@;color
		mov r6, r2 			@; @ inici fila pantalla inferior linea a escriure
		mov r7, r3 			@; @ inici pcb zocalo corresponent
		mov r8, r0 			@; num zocalo

		@;Escriure num zocalo amb color

		sub sp, #8   		@; Buscarem un espai de mem disponible per poder guardar el resultat de les operacións seguents
		mov r0, sp
		mov r9, r0 			@;Guardarem a r9 la direcció de memoria per a que no es perdi al fer les operacions
		

		mov r1, #3
		mov r2, r8
		bl _gs_num2str_dec
		mov r0, r9
		add r1, r8, #4 		@;r1 --> desplaçament fila on escriure
		mov r10, r1 		@;r10 -->guardarem per mes tard aquest desplaçament
		mov r2, #1 			@;r2 --> desplaçament columna on escriure
		mov r3, r5 			@;r3 --> color del text a escriure
		bl _gs_escribirStringSub
		add sp, #8 			@;tornarem a deixar el sp com estava

		@;Escriure num PID amb color corresponent

		ldr r2, [r7] 		@;Agafarem el PID del primer camp del pcb
		cmp r8, #0 			@;Si zocalo 0 escriurem els camps del SO
		beq .Lescriure
		cmp r2, #0 			@;Si PID = 0 y el zocalo es diferent de 0 no escriurem els camps, ja que es considera un proces que no te activitat (ompliriem la taula sense cap sentit)
		beq .LnoEscriure

		.Lescriure:

		sub sp, #8   		@; Buscarem un espai de mem disponible per poder guardar el resultat de les operacións seguents
		mov r0, sp
		mov r9, r0 			@;Guardarem a r9 la direcció de memoria per a que no es perdi al fer les operacions
		

		mov r1, #5
		bl _gs_num2str_dec
		mov r0, r9
		mov r1, r10 		@;r1 --> desplaçament fila on escriure
		mov r2, #4 			@;r2 --> desplaçament columna on escriure
		mov r3, r5 			@;r3 --> color del text a escriure
		bl _gs_escribirStringSub
		add sp, #8 			@;tornarem a deixar el sp com estava

		@;Escriure KEYNAME en color corresponent
	
		sub sp, #4 			@;Crearem espai suficient de mem a la pila per a l'string a escriure
		mov r0, sp
		ldr r1, [r7,#16] 	@;Agafadrem el KeyName del pcb corresponent
		str r1, [r0] 		@;Guardarem el KeyName al espai anteriorment creat
		mov r1, r10 		@;r1 --> desplaçament fila on escriure
		mov r2, #9 			@;r2 --> desplaçament columna on escriure
		mov r3, r5 			@;r3 ---> color del text a escriure

		bl _gs_escribirStringSub 
		add sp, #4

		b .Lfinal  			@;Un cop realitzat acabarem amb la funció

		.LnoEscriure: 		@;Si es el cas que el proces no te activitat, borrarem els camps del PID i Keyname corresponents

		ldr r0, =blancPidKeyname 	@;Espais en blanc corresponent al hueco del pid i keyname
		mov r1, r10 		@;r1 ---> desplaçament fila on escriure 
		mov r2, #4 			@;r2 ---> desplaçament columna on escriure en aquest cas el pid
		mov r3, r5  		@;r3 ---> color del text a escriure
		bl _gs_escribirStringSub

		mov r2, #9  		@;realitzarem el mateix per al Keyname
		bl _gs_escribirStringSub

		.Lfinal:

	pop {r0-r10,pc}


	.global _gg_escribirCar
	@; escribe un carácter (baldosa) en la posición de la ventana indicada,
	@; con un color concreto;
	@;Parámetros:
	@;	R0 (vx)		->	coordenada x de ventana (0..31)
	@;	R1 (vy)		->	coordenada y de ventana (0..23)
	@;	R2 (car)	->	código del caràcter, como número de baldosa (0..127)
	@;	R3 (color)	->	número de color del texto (de 0 a 3)
	@; pila (vent)	->	número de ventana (de 0 a 15)
_gg_escribirCar:
	push {r0-r9,lr}

		ldr r4 , [sp,#44]  @;Posarem a r4 el parametre de num ventana procedent de pila que serà el 5é parametre estara al offset de 44

		lsr r5 , r4, #L2_PPART	@;r5 = num_finestra / PPART --> f0=0,f1=0,f2=1,f3=1
		and r6 , r4, #3	         @;r6 num columna mirarem els 2 bits baixos de la finestra pasada per parametre

		mov r7 , #PCOLS
		mul r8 ,r7 ,r5
		mov r7 , #VFILS
		mul r9 ,r8 ,r7
		mov r7 , #VCOLS
		mul r7 ,r6, r7 
		add r7, r9
		lsl r7 ,#1 		@;Desplaçament mapa de baldoses per pantalla demanada
						@;r7=((fila_finestra*PPART*VFILS*VCOLS) + (col_finestra*VCOLS))*2
						@;Serà multiplicat per 2 perque s'utilitzen halfword

		ldr r4 , =map2Pointer	@;Direcció del punter del fondo 2
		ldr r4 , [r4]
		add r7, r4 				@;r7 adreça mem primera baldosa de la finestra demanada

		mov r5, #PCOLS*2
		mul r5 , r1				@; PCOLS*2*ColumnaBaldosa (calculem el desplaçament Y)
		mov r6 , r0, lsl #1 	@; FilaBaldosa *2 (calculem el desplaçament X)
		add r5, r6
		add r7, r5				@;r7 serà la pos de mem x,y on voldrem posar la baldosa corresponent dintre del mapa

		mov r3, r3, lsl #7 		@;Desplaçament segons el color demanat (blanc 0 * 128 -->0 , per al color groc 1*128 --> 128 ....)
		add r2, r3				@;Agafarem el caracter amb el color demanat
		strh r2, [r7]			@;Guardem el char a la posició desitjada
	
	pop {r0-r9,pc}


	.global _gg_escribirMat
	@; escribe una matriz de 8x8 carácteres a partir de una posición de la
	@; ventana indicada, con un color concreto;
	@;Parámetros:
	@;	R0 (vx)		->	coordenada x inicial de ventana (0..31)
	@;	R1 (vy)		->	coordenada y inicial de ventana (0..23)
	@;	R2 (m)		->	puntero a matriz 8x8 de códigos ASCII (dirección)
	@;	R3 (color)	->	número de color del texto (de 0 a 3)
	@; pila	(vent)	->	número de ventana (de 0 a 15)
_gg_escribirMat:
	push {r0-r9,lr}

		ldr r4 , [sp, #44]  @;Posarem a r4 el parametre de num ventana procedent de pila que serà el 5é parametre estara al offset de 44

		lsr r5 , r4, #L2_PPART	@;r5 = num_finestra / PPART --> f0=0,f1=0,f2=1,f3=1
		and r6 , r4, #3	         @;r6 num columna mirarem els 2 bits baixos de la finestra pasada per parametre

		mov r7 , #PCOLS
		mul r8 ,r7 ,r5
		mov r7 , #VFILS
		mul r9 ,r8 ,r7
		mov r7 , #VCOLS
		mul r7 ,r6, r7 
		add r7, r9
		lsl r7 ,#1 		@;Desplaçament mapa de baldoses per pantalla demanada
						@;r7=((fila_finestra*PPART*VFILS*VCOLS) + (col_finestra*VCOLS))*2
						@;Serà multiplicat per 2 perque s'utilitzen halfword

		ldr r4 , =map2Pointer	@;Direcció del punter del fondo 2
		ldr r4 , [r4]
		add r7, r4 				@;r7 adreça mem primera baldosa de la finestra demanada

		mov r5, #PCOLS*2
		mul r5 , r1				@; PCOLS*2*ColumnaBaldosa (calculem el desplaçament Y)
		mov r6 , r0, lsl #1 	@; FilaBaldosa *2 (calculem el desplaçament X)
		add r5, r6
		add r7, r5				@;r7 serà la pos de mem x,y on voldrem posar la baldosa corresponent dintre del mapa

		mov r3, r3, lsl #7 		@;Desplaçament segons el color demanat (blanc 0 * 128 -->0 , per al color groc 1*128 --> 128 ....)

		mov r0 , #0 			@;Contador files finestra
		mov r1 , #0 			@;Contador matriu


		.LbucleFiles:

			cmp r0, #8 			@;Comprovem que no hem arribat al maxim de dimensio
			beq .LfinalBucle

			mov r5, #0 			@;Contador columnes finestra

			.LbucleColumnes:

				cmp r5, #16 	@;Si arribem al total de columnes anem a la seguent fila
				beq .LseguentFila

				ldrb r4,[r2,r1]		@;Carreguem valor de la matriu
				
				cmp r4 , #0 		@;Si arribem al centinela, tractarem el seguent
				beq .Lseguentchar
				sub r4, #32 		@;Resta per poder agafar el numero de baldosa corresponent
				add r4, r3 			@;Increment del valor del num de baldosa pel canvi de color
				strh r4, [r7,r5]	@;Guardarem la baldosa corresponent a la seva posició de la finestra

				.Lseguentchar:
				add r5, #2 			@;Increment contador columnes per la pantalla
				add r1, #1 			@;Increment contador matriu

				b .LbucleColumnes

		.LseguentFila:

			add r7, #2*PCOLS 		@;Incrementarel la dir mem del mapa fins a la primera posició de la seguent fila
			add r0, #1 				@;Incrementem el contador de files
			b .LbucleFiles

		.LfinalBucle:
		
	pop {r0-r9,pc}



	.global _gg_rsiTIMER2
	@; Rutina de Servicio de Interrupción (RSI) para actualizar la representa-
	@; ción del PC actual.
_gg_rsiTIMER2:
	push {r0-r9,lr}

		ldr r6 ,=_gd_pcbs 		@;Adreça base pcbs
		mov r4 ,#24 			@;Desplaçament a r4 dels parametres del pcb (6 parametres * 4 size de cada un)
		mov r3 ,#0 				@;Color a aplicar (blanc)
		mov r7 ,#0 				@;Contador zocalos

		.LbucelRecorrerZocalos:
			mla r5, r7, r4, r6 	@; r7 --> direcció memoria inici pcb del zocalo actual
			cmp r7 , #0 		@;Si es el sistema operatiu mostrarem el pc
			beq .LmostrarPC
			ldr r8 , [r5]
			cmp r8 , #0
			beq .LborrarPc  @;Si el zocalo no te cap proces actiu, borrarem el camp de pc de la taula i pasarem al seguent

		.LmostrarPC:
			add r5, #4 			@;Desplaçament al camp de PC dintre del pcb
			sub sp, #14 		@;Reservarem espai a una zona lliure de memoria
			mov r0, sp 			@;I guardarem a r0 i a r9 la dir de mem en la primera posició, tal com hem fet a la funció de _gg_escribirLineaTabla
			mov r9, sp

			mov r1, #9 			@;r1 --> longitud de la cadena
			ldr r2, [r5]		@;r2 --> PC actual del proces
			bl _gs_num2str_hex
			mov r0, r9
			add r1, r7, #4 		@;r1 ---> fila del zocalo tractant-se en la pantalla inferior
			mov r2, #14 		@;Columna on guardar el resultant PC
			bl _gs_escribirStringSub

			add sp, #14 		@;Tornem a deixar el punter de pila tal com estava
			b .LmirarSeguent
		.LborrarPc:

			ldr r0 ,= blancPc 		@;r0 ---> espais en blancs corresponent al tamany del pc per borrarlo
			add r1, r7, #4  		@;r1 ---> desplaçament fila del zocalo tractant-se
			mov r2, #14 			@;r2 ---> desplaçament columna on estara el pc
			bl _gs_escribirStringSub

		.LmirarSeguent:

			add r7, #1 			@;Incrementem contador zocalos
			cmp r7, #NVENT 		@;Mirem que no exedim el num max de finestres a comprovar
			blo .LbucelRecorrerZocalos
		
	pop {r0-r9,pc}


.end
