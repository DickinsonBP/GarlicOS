/*------------------------------------------------------------------------------

	"CUA4.c" : Programa hecho por Dickinson Bedoya Perez;
	
	Obtener num. aleatorio [0..25^(arg+1)] y su suma con 4 cuadrados (Lagrange)

------------------------------------------------------------------------------*/
#include <GARLIC_API.h>


unsigned int quo;
unsigned int res;

unsigned int i,j,k,l;

int num = 1;

void calculaLagrange(unsigned int num){
	for(i = 0; i*i <= num; i++){
		//GARLIC_delay(0);
		//GARLIC_printf("i: %d\n",i);
        for(j = i; j*j <= num; j++){
			//GARLIC_printf("j: %d\n",j);
            for(k = j; k*k <= num; k++){
				//GARLIC_printf("k: %d\n",k);
                for(l = k; l*l <= num; l++){
					//GARLIC_printf("l: %d\n",l);
                    if((i*i) + (j*j) + (k*k) + (l*l) == num){
						GARLIC_printf("----RESULT----\n");
                        GARLIC_printf("%d^2 + %d^2 +\n",i,j);
						GARLIC_printf("%d^2 + %d^2\n",k,l);
                    }
                }
            }
        }
	}	
}


int _start(int arg){//cambiar mair por _start
    if (arg < 1) arg = 1;			// limitar valor máximo y 
	arg += 1; //arg+1

	GARLIC_clear();
	
    GARLIC_printf("-- Programa CUA4  -  PID (%d) --\n", GARLIC_pid());

	GARLIC_divmod(GARLIC_random(),26,&quo,&res);//obtener numero aleatorio entre 0 y 25
	if(res < 1){
		res++;
	}
	GARLIC_printf("Numero aleatorio a calcular: %d\n", res);
	
    for(i = arg; i > 0; i--){
		num = num * res;
	}

    GARLIC_printf("Numero elveado a (%d + 1): %d\n",arg-1,num);
	calculaLagrange(num);
	
    return 0;
}