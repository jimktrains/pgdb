#include <stdio.h>
#include <string.h>
#include <time.h>

unsigned long fib_rec(int num);
unsigned long fib_it(int num);

int main(int argc, char* argv[]){
	int num;
	unsigned long  res;
	double timediff;
	if(argc != 3){
		printf("USAGE: fib rec|it num\n num is 1 based");
		return 0;
	}

	num = atoi(argv[2]);
	
	if(!strcmp(argv[1], "rec")){
		res = fib_rec(num);
	} else if (!strcmp(argv[1], "it")){
		res = fib_it(num);
	}
	
	printf("Fibonacci[%d] = %d\n", num, res);
	printf("Time: %d ticks\n", clock());
	return 0;
}

unsigned long fib_rec(int num){
	if(num == 1 || num == 2 || num < 1) return 1;
	return fib_rec(num - 1) + fib_rec(num - 2);
}

unsigned long fib_it(int num){
	unsigned long l1 = 1;
	unsigned long l2 = 1;
	unsigned long tmp;
	int i;
	for(i = 3; i <= num; i++){
		tmp = l1;
		l1 += l2;
		l2 = tmp;
	}

	return l1;
}
