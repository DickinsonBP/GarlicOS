/*------------------------------------------------------------------------------

	"garlic_mem.c" : fase 2 / programador M / Dickinson Bedoya Perez

	Funciones de carga de un fichero ejecutable en formato ELF, para GARLIC 1.0

------------------------------------------------------------------------------*/
#include <nds.h>
#include <filesystem.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h> /* Libreria para gestion de direcotorios */

#include <garlic_system.h>	// definicion de funciones y variables de sistema

#define INI_MEM 0x01002000		// dirección inicial de memoria para programas
#define PT_LOAD 1

unsigned int next = INI_MEM;			//direccion de los programas, ira incrementando


/* _gm_initFS: inicializa el sistema de ficheros, devolviendo un valor booleano
					para indiciar si dicha inicialización ha tenido éxito; */
int _gm_initFS()
{
	return nitroFSInit(NULL);
}

/* _gm_listaProgs: devuelve una lista con los nombres en clave de todos
			los programas que se encuentran en el directorio "Programas".
			 Se considera que un fichero es un programa si su nombre tiene
			8 caracteres y termina con ".elf"; se devuelven sólo los
			4 primeros caracteres de los programas (nombre en clave).
			 El resultado es un vector de strings (paso por referencia) y
			el número de programas detectados */
int _gm_listaProgs(char* progs[])
{
	char *name, *fileName, *ext;
	int numFiles = 0;
	struct dirent *program; /*Programa*/
	
	DIR *dir = opendir("Programas/");

	program = readdir(dir); /* Lectura de la primera entrada del directorio */

	while(program != NULL){
		/* Comprobar que el nombre de los archivos sean de longitud 8 */
		if(strlen(program->d_name) == 8){	/*XXXX.elf*/
			/* Reservar memoria para los nombres */
			name = (char*) malloc(sizeof(char)*8);
			fileName = (char*) malloc(sizeof(char)*4);
			ext = (char*) malloc(sizeof(char)*4);
			
			/* Comprobar que no sean nulos los valores */
			if((name != NULL) && (fileName != NULL) && (ext != NULL)){
				strncpy(name, program->d_name, 8); //copiar nombre en el string
				name[8] = '\0'; //Añadir fin de string
				strncpy(ext, &name[4],4); //coger la extension del archivo, ultimos cuatro caracteres
				ext[4] = '\0';
				
				/* Comprobar que sea de tipo ELF */
                if(strcmp(ext, ".elf") == 0){
					strncpy(fileName,&name[0],4); //coger solo el nombre del archivo
					progs[numFiles] = fileName;
					numFiles++;
				}
				free(name);
				free(ext);
				//free(fileName);
			}
		}
		
		program =readdir(dir); /* Siguiente entrada */
	}

	return numFiles;
}


/*
	Rutina propia para obtener datos a partir del desplazamiento usando la direccion de memoria inicial,
	del offset y del tamaño en bytes que ocupa
*/
int _gm_Desplazamiento(char *mem, int offset, int size)
{
	int result=0;
	
	for(int i=0;i<size;i++)
	{
		result += *(mem+offset+i) << i*8; //desplazar a la izquierda i*8 bits
		
	}
	return result;
}

/* _gm_cargarPrograma: busca un fichero de nombre "(keyName).elf" dentro del
					directorio "/Programas/" del sistema de ficheros, y
					carga los segmentos de programa a partir de una posición de
					memoria libre, efectuando la reubicación de las referencias
					a los símbolos del programa, según el desplazamiento del
					código en la memoria destino;
	Parámetros:
		keyName ->	vector de 4 caracteres con el nombre en clave del programa
	Resultado:
		!= 0	->	dirección de inicio del programa (intFunc)
		== 0	->	no se ha podido cargar el programa
*/
intFunc _gm_cargarPrograma(int zocalo, char *keyName)
{
	int startAddress[2];
	int destAddress[2];
	char path[19]; /*Path de 19 caracteres con formato --> /Programas/HOLA.elf*/
	char *file;
	int file_size;
	/*variables para la cabecera el archivo ELF*/
	unsigned int e_entry = 0, e_phoff, e_phentsize;	
	unsigned short e_phnum;
	/*
		e_entry --> variable para punto de inicio del programa
		e_phoff --> variable para desplazamiento de la tabla de segmentos
		e_phnum --> numero de entradas de la tabla de segmentos
		e_phentsize --> tamaño de cada entrada de la tabla de segmentos (size of program headers)
	*/
	/*---------------------------------------*/
	/*variables para la tabla de segmentos*/
	unsigned int p_type,p_offset,p_memsz;
	/*
		p_type --> tipo del segmento, solo cargar del tipo 1
		p_offset --> desplazamiento en el fichero del primer byte del segmento
		p_paddr --> direccion fisica donde se tendria que cargar el segmento
		p_filesz --> tamaño del segmento dentro del fichero
		p_memsz --> tamaño del segmento dentro de memoria
	*/
	int offset = 0, result=0;
	/*
		offset --> offset
		actual --> variable para el indice del segmento actual
		copia --> variable para las copias en memoria
		result --> variable para comprobar si se ha podido cargar o no el programa. Devuelve puntero al inicio del programa cargado
	*/
	
	FILE *f; /*variable para proximo archivo .elf*/
	
	sprintf(path,"/Programas/%s.elf",keyName); /*generar path*/
	
	f = fopen(path, "rb");//abrir archivo de bytes en modo lectura
	if(f != NULL){
		
		/*Tratar archivo*/
		fseek(f,0,SEEK_END);
		file_size = ftell(f);
		file = malloc(file_size);
		fseek(f,0,SEEK_SET);
		if(file == NULL){
			//fallo al cargar memoria
			fclose(f);
			free(file);
			exit(0);
		}
		/* usar la funcion size_t fread para comprobar que el archivo se lea bien y guardarlo en el buffer*/
		if(fread(file,1,file_size,f) == file_size){
			/*Obtener datos a partir del offset y el tamaño*/
			/*Offsets calculados*/
			e_entry = _gm_Desplazamiento(file,24,4); //e_entry: offset = 0x18(=24d), size = 4bytes. Entrada del programa
			e_phoff = _gm_Desplazamiento(file,28,4); //e_phoff: offset = 0x1C(=28d), size = 4bytes. Offset del program header
			e_phentsize = _gm_Desplazamiento(file,42,2); //e_phentsize: offset = 0x2A(=42d), size = 2bytes. Valor de la medida de una entrada del program header
			e_phnum = _gm_Desplazamiento(file,44,2); //e_phoff: offset = 0x2C(=44d), size = 2bytes. Numero de entradas en la tabla de segmentos (iterar en este valor)
			
			/*Acceder a la tabla de segmentos (con e_phnum segmentos)*/
			for(int i=0; i< e_phnum; i++){
				/*calcular la posicion en la tabla de segmentos*/
				/*Apunta al nuevo segmento*/
				offset = e_phoff + i * e_phentsize;
				
				/*obtener datos a partir de la posicion*/
				p_type = _gm_Desplazamiento(file,offset,4); //p_type: offset = 0x00(=0d), size = 4bytes
				
				/*acceder a la tabla si p_type es del tipo PT_LOAD(=1)*/
				if(p_type == PT_LOAD){
					/*Obtener la direccion de memoria inicial del segmento a cargar (p_paddr)*/
					startAddress[i] = _gm_Desplazamiento(file,12+offset,4); //p_paddr: offset = 0x0C(=12d), size = 4bytes
					/*obtener tamaño del segmento dentro de memoria*/
					p_memsz = _gm_Desplazamiento(file,20+offset,4); //p_offset: offset = 0x14(=20d), size = 4bytes
					
					/*Obtener el desplazamiento dentro del fichero donde empieza el segmento*/
					p_offset = _gm_Desplazamiento(file,4+offset,4); //p_offset: offset = 0x04(=4d), size = 4bytes
					
					
					destAddress[i] = (int) _gm_reservarMem(zocalo, p_memsz, i); //Reservar memoria
					if(destAddress[i] != 0){
						/*Cargar el contenido del segmento a partir de una direccion de memoria destino apropiada*/
						_gs_copiaMem(&file[p_offset],(void *)destAddress[i], p_memsz);
						
						/*calculo de puntero al inicio del programa cargado*/
						if(i == 0) result = e_entry - startAddress[i] + destAddress[i];
					} 
					else{
						/*No se ha podido cargar el programa*/
						result = 0;
						if(i != 0)_gm_liberarMem(zocalo);
					}
				}
			}
			if(result != 0){
				_gm_reubicar(file, startAddress[0], (unsigned int*) destAddress[0], startAddress[1],(unsigned int*) destAddress[1]);
			}
		}
		/*liberar memoria y cerrar archivo*/
		free(file); 
	}else{
		//no existe el archivo
		result = 0;
	}
	fclose(f);
	
	return ((intFunc) result);
}
