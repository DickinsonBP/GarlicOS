/*------------------------------------------------------------------------------

	"garlic_graf.c" : fase 2 / programador G

	Funciones de gestión de las ventanas de texto (gráficos), para GARLIC 2.0

------------------------------------------------------------------------------*/
#include <nds.h>

#include <garlic_system.h>	// definición de funciones y variables de sistema
#include <garlic_font.h>	// definición gráfica de caracteres

/* definiciones para realizar cálculos relativos a la posición de los caracteres
	dentro de las ventanas gráficas, que pueden ser 4 o 16 */
#define NVENT	16				// número de ventanas totales
#define PPART	4				// número de ventanas horizontales o verticales
								// (particiones de pantalla)
#define VCOLS	32				// columnas y filas de cualquier ventana
#define VFILS	24
#define PCOLS	VCOLS * PPART	// número de columnas totales (en pantalla)
#define PFILS	VFILS * PPART	// número de filas totales (en pantalla)


const unsigned int char_colors[] = {240, 96, 64};	// amarillo, verde, rojo
const char blancPidKeyname[] ="    ";
const char blancPc[] ="        ";
int num_paletes = 4;
u16* map3Pointer;
u16* map2Pointer;
int bg2,bg3;


/* _gg_generarMarco: dibuja el marco de la ventana que se indica por parámetro,
												con el color correspondiente */
void _gg_generarMarco(int v, int color)
{
	//De forma parametrica mirarem els quadrants de les finestres per veure les 
	//seves @ d'inici del mapa
	int fila_finestra = v/PPART;		//Per a finestres 0 i 1 = 0, 2 i 3 = 1
	int col_finestra = v%PPART;			//Per a finestres 0 i 2 = 0, 1 i 3 = 1
	//Agafarem la @ base del map del bg3
	map3Pointer = bgGetMapPtr(bg3);
	int BaseFinestra = (fila_finestra*PPART*VFILS*VCOLS) + (col_finestra*VCOLS);
	int color_indicat = color*128;

	//Puntes dels marcs
	map3Pointer[BaseFinestra] = 103 + color_indicat;
	map3Pointer[BaseFinestra + VCOLS-1] = 102 + color_indicat;
	map3Pointer[BaseFinestra + (VFILS-1)*PCOLS + VCOLS-1] = 101 + color_indicat;
	map3Pointer[BaseFinestra + (VFILS-1)*PCOLS] = 100 + color_indicat;
	//Bordes dels marcs
	int i;
	//superiors e inferiors
	for(i = BaseFinestra+1;i<BaseFinestra+VCOLS-1;i++)
	{
		map3Pointer[i] = 99 + color_indicat;
		map3Pointer[i +(VFILS-1)*PCOLS] = 97 + color_indicat;
	}
	//Esquerra i dreta
	for(i = BaseFinestra+PCOLS;i<BaseFinestra+(VFILS-1)*PCOLS;i+=PCOLS)
	{
		map3Pointer[i] = 96 + color_indicat;
		map3Pointer[i +VCOLS-1] = 98 + color_indicat;
	}
}


/* _gg_iniGraf: inicializa el procesador gráfico A para GARLIC 2.0 */
void _gg_iniGrafA()
{
	int i,j;
	//Inicialitzar procesador gràfic(A) en mode 5 
	//+ reservar banc mem A + surtida top Screen
	videoSetMode(MODE_5_2D);
	vramSetBankA(VRAM_A_MAIN_BG_0x06000000);
	lcdMainOnTop();

	//Tamaño mapa = 64x64 posiciones * 2 bytes/posición= 8 Kbytes
	//Tamaño baldosas = 128 baldosas * 8x8 píxeles/baldosa * 1 byte/píxel= 8Kbytes
	//Fondos gràfics 2 i 3 en mode Extended Rotation, tamany 1024x1024
	bg2 = bgInit(2,BgType_ExRotation,BgSize_ER_1024x1024,0,4);
	bg3 = bgInit(3,BgType_ExRotation,BgSize_ER_1024x1024,16,4);

	//fondo 3 en més prioritat que el 2
	bgSetPriority(bg2,1);
	bgSetPriority(bg3,0);

	//Crearem els punters per als fondos respectius
	map2Pointer = bgGetMapPtr(bg2);
	

	//descomprimir contingut font de lletres 4 vegades
	// al background2 (0x06010000) el tamany de cada un sera de 128*64 treballant en 
	//halfword serà de 4096 el tamany de cada paleta

	for(i=0; i<num_paletes; i++)
	{
		decompress(garlic_fontTiles,bgGetGfxPtr(bg2)+i*4096,LZ77Vram);
	}

	//Punter al inici de les paletes de color, ja que la primera es la blanca
	u16* paleta_colors = bgGetGfxPtr(bg2) + 4096;

	//Pintarem les paletes seguents amb el color corresponent
	for( i = 0; i < num_paletes-1; i++)
	{
		for(j = 0; j < 4096; j++)
		{
			if((paleta_colors[j] & 0xFF) != 0)
			{
				paleta_colors[j] &= 0xFF00;
				paleta_colors[j] |= char_colors[i];
			}
			if((paleta_colors[j] & 0xFF00) != 0)
			{
				paleta_colors[j] &= 0xFF;
				paleta_colors[j] |= char_colors[i] << 8;
			}
		}
		paleta_colors +=4096;
	}
	//Copiar la font de lletres
	dmaCopy(garlic_fontPal,BG_PALETTE,sizeof(garlic_fontPal));

	//escalar els fondos 2 i 3 en reducció al 50%
	bgSetScale(bg2,0x200,0x200);
	bgSetScale(bg3,0x200,0x200);

	bgUpdate();
	//generar els marcs de les finestres
	for (int i=0;i<NVENT;i++) _gg_generarMarco(i,3);	
	 
}



/* _gg_procesarFormato: copia los caracteres del string de formato sobre el
					  string resultante, pero identifica los códigos de formato
					  precedidos por '%' e inserta la representación ASCII de
					  los valores indicados por parámetro.
	Parámetros:
		formato	->	string con códigos de formato (ver descripción _gg_escribir);
		val1, val2	->	valores a transcribir, sean número de código ASCII (%c),
					un número natural (%d, %x) o un puntero a string (%s);
		resultado	->	mensaje resultante.
	Observación:
		Se supone que el string resultante tiene reservado espacio de memoria
		suficiente para albergar todo el mensaje, incluyendo los caracteres
		literales del formato y la transcripción a código ASCII de los valores.
*/
void _gg_procesarFormato(char *formato, unsigned int val1, unsigned int val2,
																char *resultado)
{
	int contador_f=0, contador_r=0,cont_vector=0;
	char char_seguent, string2Int[16],string2Hexa[16], primer=0,segon=0;
	char * char_especial;
	unsigned int valor =0;

	//recorregut de l'string en codigos de formato
	while(formato[contador_f] !='\0' && contador_f<VCOLS*3)
	{
		//Mirem si hi ha un codigo de formato en la posicio actual
		//i guardarem els valors a transcriure a valor;
		if(formato[contador_f]=='%' && (!primer || !segon))
		{
			char_seguent = formato[contador_f+1];

			if(char_seguent == 'd' || char_seguent =='x' || char_seguent == 's' || char_seguent == 'c')
			{
				if(!primer)
				{
					valor = val1;
					primer = 1;
				}
				else
				{
					valor = val2;
					segon = 1;
				}
			}

			//Farem el tractament particular en cada cas amb un switch
			switch(char_seguent)
			{
				//numero codi ASCII
				case 'c':
						char_especial = (char*) valor;
						resultado[contador_r] = (unsigned int) char_especial;
						contador_r++;
						contador_f+=2;
						break;
				//numero natural
				case 'd':
						_gs_num2str_dec(string2Int,16,valor);
						cont_vector=0;
						while(string2Int[cont_vector]!='\0')
						{
							if(string2Int[cont_vector]==' ') cont_vector++;
							else
							{
								resultado[contador_r] = string2Int[cont_vector];
								cont_vector++;
								contador_r++;
							}
							
						}
						contador_f+=2;
						break;
				//numero hexa
				case 'x':
						_gs_num2str_hex(string2Hexa,16,valor);
						cont_vector=0;
						while(string2Hexa[cont_vector]!='\0')
						{
							resultado[contador_r] = string2Hexa[cont_vector];
							cont_vector++;
							contador_r++;
						}
						contador_f+=2;
						break;
				//string
				case 's':
						char_especial = (char*) valor;
						cont_vector=0;
						while(char_especial[cont_vector]!='\0')
						{
							resultado[contador_r] = char_especial[cont_vector];
							contador_r++;
							cont_vector++;
						}
						
						contador_f+=2;
						break;
				case '%':
						resultado[contador_r] = formato[contador_f];
						contador_r++;
						contador_f+=2;
						break;
				//procediment natural
				default:
						resultado[contador_r] = formato[contador_f];
						contador_r++;
						contador_f++;

			}

		}
		//En el cas que no sigui cap cas anterior fara el pas normal 
		//de vector formato a vector resultat del contingut
		else
		{
			resultado[contador_r] = formato[contador_f];
			contador_r++;
			contador_f++;
		}
	}
	//Si ja hem acabat ens tocara posar el centinela al final del
	//vector resultat, per al tractament a la funció _gg_escribir
	resultado[contador_r]='\0';

}


/* _gg_escribir: escribe una cadena de caracteres en la ventana indicada;
	Parámetros:
		formato	->	cadena de formato, terminada con centinela '\0';
					admite '\n' (salto de línea), '\t' (tabulador, 4 espacios)
					y códigos entre 32 y 159 (los 32 últimos son caracteres
					gráficos), además de marcas de format %c, %d, %h y %s (max.
					2 marcas por cadena) y de las marcas de cambio de color 
					actual %0 (blanco), %1 (amarillo), %2 (verde) y %3 (rojo)
		val1	->	valor a sustituir en la primera marca de formato, si existe
		val2	->	valor a sustituir en la segunda marca de formato, si existe
					- los valores pueden ser un código ASCII (%c), un valor
					  natural de 32 bits (%d, %x) o un puntero a string (%s)
		ventana	->	número de ventana (de 0 a 3)
*/
void _gg_escribir(char *formato, unsigned int val1, unsigned int val2, int ventana)
{
	//String on guardarem el resultat del missatge
	char resultat[VCOLS*4];

	//conversió d'string de format
	_gg_procesarFormato(formato,val1,val2,resultat);

	//Agafarem els 4 bits alts que seran el color del text a escriure
	int color_text = _gd_wbfs[ventana].pControl >> 28;

	//Obtenció fila actual i num de caracters pendents
	int fila_actual = ((_gd_wbfs[ventana].pControl & 0xFFF0000) >> 16);
	int caracters_almacenats = (_gd_wbfs[ventana].pControl & 0xFFFF);
	int contador;

	for(contador=0; resultat[contador] != '\0';contador++)
	{
		//Control del color de text
		if(resultat[contador] == '%')
		{
			char char_seguent = resultat[contador+1];
			if(char_seguent >= '0' && char_seguent <= '3')
			{
				contador+=2;
				//guardarem a la var int color_text si es (0 ->blanc,1->groc,2->verd,3->roig)
				color_text = char_seguent - '0';
			}
		}
		//Si es un tabulador, espais fins a múltiple de 4
		if(resultat[contador] == 9)
		{
			while(caracters_almacenats %4 !=0)
			{
				_gd_wbfs[ventana].pChars[caracters_almacenats] = ' ';
				caracters_almacenats++;
				_gd_wbfs[ventana].pControl +=1; 
			}

		}
		else if(resultat[contador] == 10)
		{
			while(caracters_almacenats != VCOLS)
			{
				_gd_wbfs[ventana].pChars[caracters_almacenats] = ' ';
				caracters_almacenats++;
				_gd_wbfs[ventana].pControl +=1; 
			}

		}
		//Si es un espai
		else if(resultat[contador] == 32)
		{	
			_gd_wbfs[ventana].pChars[caracters_almacenats] = ' ';
			caracters_almacenats++;
			_gd_wbfs[ventana].pControl +=1; 
		}
		//si caracter literal, afegir-lo tal cual
		else if((resultat[contador] > 32) && (resultat[contador] <= 126))
		{	
			//guardarem al buffer el carcater corresponent amb el seu color (4 paletes de color de 128, posició)
			_gd_wbfs[ventana].pChars[caracters_almacenats] = resultat[contador] + color_text*128;
			caracters_almacenats++;
			_gd_wbfs[ventana].pControl +=1; 
		}
		
		//Si hem arribat al màxim de caracters (32 caracters) a analitzar per a la linea
		if(caracters_almacenats == VCOLS)
		{
			//retroces vertical per asegurar que el controlador de gràfics
			//no estigue accedint a la mem de video
			_gp_WaitForVBlank();

			if(fila_actual ==VFILS)
			{
				//Scroll cap a d'alt
				_gg_desplazar(ventana);
				fila_actual = VFILS -1;
			}
			//transferir els caracters del buffer sobre les posis de mem de video
			_gg_escribirLinea(ventana,fila_actual,caracters_almacenats);
			//Si encara no hem arribat a la linea final, re-iniciem variables
			//per a la seguent linea
			if(fila_actual != VFILS)
			{
				fila_actual++;
				
			}
			caracters_almacenats=0;
			_gd_wbfs[ventana].pControl=0;
		}
	}
	_gd_wbfs[ventana].pControl = (color_text << 28) | (fila_actual << 16) | caracters_almacenats;
}
