
#include <GARLIC_API.h>			/* definición de las funciones API de GARLIC */
int _start(int arg) {
//------------------------------------------------------------------------------
	unsigned int i, j, z, num, num_xifres=0;
	unsigned int quo, mod;
	unsigned int calcul_final =0, cal;

	GARLIC_printf("%1 -- Programa AMST  -  PID (%d) --\n", GARLIC_pid());
	
	j = 1;							// j = càlcul de 10^ arg+3
	for (i = 0; i < (arg+3); i++)
	{	
		j *= 10;
	}
	
	for (i = 0; i <= j; i++)		//bucle general agafa valors de 0 fins 10^ arg+3
	{
		num = i;
		while (num >0)								//mirem el numero de xifres que te el valor del bucle actual fins que el num dividit sigui major a 0
		{
			GARLIC_divmod(num, 10, &quo, &mod);		//fent divisions per 10 
			num = quo;								//agafem el quocient d'aquesta divisio per més tard tornar-la a fer si es el cas
			num_xifres++;							//aumentem +1 el numero de xifres
		}
		
		num = i;
		
		while (num >0)								//càlcul del numero d'Amstrong en el cas que el numero sigui > a 0
		{
			GARLIC_divmod(num, 10, &quo, &mod);		//dividim entre 10 el numero actual 
			cal = 1;								//cal, serà l'inici de fer l'elevat de la xifra
			for ( z=0; z < num_xifres ; z++)		//bucle per fer l'elevat del modul depenent el numero de xifres
			{
				cal *= mod ;						
			}
			calcul_final = calcul_final + cal;		//sumem el modul actual amb el calcul dels elevats dels moduls anteriors
			
			num = quo;								//declarem com a num a tractar un altre cop el quocient de la divisio feta
		}
		
		if (calcul_final == i)	GARLIC_printf("(%d)\t%d %2 = Num d'Amstrong!\n", GARLIC_pid(),calcul_final); //en el cas que la suma de cada una de les xifres^al num 
																										//de xifres total sigui igual al numero inicial serà num d'Amstrong
																									    //a més printarem de color ver que ho és!!
		num_xifres = 0;									//iniciem el num_xifres i calcul_final per fer la seguent comprovació
		calcul_final=0;
	}	

	return 0;
}