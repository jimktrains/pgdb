/*
    pgdb is a wrapper allowing the output of multiple programs to be recieved
      and used at a single terminal
    Copyright (C)  2009 Jim Keener

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    You can contact the author via email at jkeener@psc.edu or snail mail at:
         James Keener
         Pittsburgh Supercomputing Center
         300 S. Craig St.
         Pittsburgh, Pa 15312
*/
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

unsigned long fib_rec(int num);
unsigned long fib_it(int num);

int main(int argc, char* argv[]){
	int num;
	unsigned long  res;
	double timediff;
	char dbg[80];
	if(argc != 3){
		printf("USAGE: fib rec|it num\nnum is 1 based\n");
		return 0;
	}
	sprintf(dbg, "perl -w client.pl %s %d 1 &", argv[0], getpid());

	system(dbg);
	sleep(5);
	num = atoi(argv[2]);
	
	if(!strcmp(argv[1], "rec")){
		res = fib_rec(num);
	} else if (!strcmp(argv[1], "it")){
		res = fib_it(num);
	}
	
	printf("Fibonacci[%d] = %u\n", num, res);
	printf("Time: %d ticks\n", clock());
	return 0;
}

unsigned long fib_rec(int num){
	if(num < 1) return 0;
	if(num == 1 || num == 2) return 1;
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
