/*------------------------------------------------------------------------------

	"POT2.c" : Programa hecho por Anna Gracia Colmenarejo;
	
	Detectar potencias de 2 en la lista de (arg+2)^3 alea. [0..2^(arg+4)]

------------------------------------------------------------------------------*/
#include <GARLIC_API.h>

int _start(int arg){		//funcion de inicio

	GARLIC_printf("-- Programa POT2 - PID (%d) --\n", GARLIC_pid());
    
	unsigned int n, quo, elevado, max, res, longitud;
	max = 1;
	elevado = arg + 4;
	longitud = (arg+2)*(arg+2)*(arg+2); //longitud de la litsa
	if (arg < 0) arg = 0;			// limitar valor mínimo del argumento 
	if (arg > 3) arg = 3;			// limitar retardo máximo 3 segundos
	
	for(int i=0; i<elevado; i++){	//max num aleatorio
		max= max*2;
	}
	res=0;
	
	for(int i=0; i<longitud; i++){
		GARLIC_delay(arg);
		GARLIC_divmod(GARLIC_random(),max+1,&quo,&n);
		if(n!=0){
			res = n && (0 == (n & (n-1)));
			if (res)
				GARLIC_printf("%d es potencia\n", n);
			else 
				GARLIC_printf("%d no es potencia\n", n);
		}else GARLIC_printf("%d es potencia\n", n);
	}

	return 0;
	
}