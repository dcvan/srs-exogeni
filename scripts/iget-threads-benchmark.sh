#!/bin/bash

for ((n=0;n<=8;n+=2));do
	echo -e "iget transfering with $n threads ..." | tee -a runtime.txt
	IGET_RUNTIME=$({ time iget -rN $n genomicdata; } 2>&1 | awk '/real.*/{print $2}')
	rm -rf genomicdata
	echo -e "iget runtime: $IGET_RUNTIME" | tee -a runtime.txt;
done;
echo -e "scp transferring ..." | tee -a runtime.txt
SCP_RUNTIME=$({ time sshpass -p pegasus scp -r pegasus-user@152.54.14.13:~/genomicdata .; } 2>&1 | awk '/real.*/{print $2}')
echo -e "scp runtime: $SCP_RUNTIME" | tee -a runtime.txt
rm -rf genomicdata
