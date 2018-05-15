#! /bin/bash

# Global Varibales.
auth_count=0 # All auth count.
totally_failed_count=0 # Totally failed auth count.
interval=('5s' '1m' '30m') # Intervals to sleep for different scences.
interface=('LOGI_MIX2' 'BIGBANG' 'KGFAN' 'LOGI_MX4') # All interfaces.
# All accounts.
program='/usr/fchinanet/core'
account[0]=' -a 15380835649 -p .rhswdzbdbh-4609'
account[1]=' -a 17714366657 -p bigbang'
account[2]=' -a 17714366659 -p lyp82ndlf'
online_option[0]=' -t 0 -bt'
online_option[1]=' -t 1 -bt'
log_on=1 # Open the log with num 1 or not with 0.

# Initial And Clean Works.
handle_date(){
	datefile='/usr/fchinanet/date'
	[[ $1 -eq 1 ]] && return $( < $datefile)
	sleep ${interval[1]} && echo $(date +%j) > $datefile
}

initial_work(){
	write2log 1
	for (( i = 0; i < ${#interface[@]}; i++ )); do
		result[i]=0
	done
	for (( i = 1; i < ${#auth_string[@]}; i++ )); do
		# Num 3 need to be changed if there be more or less accounts.
		[[ i > 3 ]] && j=1 || j=0
		auth_string[i]=${program}${account[`expr $i % 3 -1`]}${online_option[$j]}
	done
	handle_date 1
	idx=`expr $? % 3 + 4`
	auth_string[0]=${auth_string[$idx]}
}

clean_work(){
	mwan3 restart 1>/dev/null 2>&1
	handle_date 0
	write2log 3 'ALL ONLINE!'
	maintain_func
}

# Network Operations.
commit_network_config(){
	uci commit network
	/etc/init.d/network reload
	sleep ${interval[0]}
}

metric_recovery(){
	for (( i = 0; i < ${#interface[@]}; i++ )); do
		uci set network.${interface[$i]}.metric=$[ i + 100 ]
	done
	commit_network_config
}

reset_network(){
	/etc/init.d/network restart && sleep ${interval[0]}
	# Num i need to be reconsidered based on what network interface configs you have.
	for (( i = 1; i < ${#interface[@]}; i++ )); do
		ip link add link eth0.2 name "veth$i" type macvlan
		ifconfig "veth$i" up
	done
	metric_recovery && sleep ${interval[0]}
}

# Core Auth Process.
triple_auth(){
	uci set network.${interface[$1]}.metric=1 && commit_network_config
	for (( i = 0; i < 3; i++ )); do
		write2log 2 "[AUTH_${interface[$1]}] $(${auth_string[$1]})"
		is_connected
		if [[ $? -eq 1 ]]; then
			for (( j = 0; j < ${#result[@]}; j++ )); do
				[[ "${interface[$1]}" == ${interface[$j]} ]] && result[$j]=1
			done
			metric_recovery && return
		fi
		sleep ${interval[0]}
	done
	metric_recovery
}

# Assistant Auth Logic.
write2log(){
	[[ log_on -eq 0 ]] return
	logfile='/usr/fchinanet/log'
	[[ $1 -eq 1 ]] [[ -f $logfile ]] && rm -rf $logfile && return
	[[ $1 -eq 2 ]] echo ${@:2} >> $logfile && return
	[[ $1 -eq 3 ]] echo "---------------------${@:2}---------------------" >> $logfile

}

is_connected(){
	ping -c 3 -w 5 www.baidu.com
	[[ $? -eq 0 ]] && return 1
	return 2
}

reboot_logic(){
	[[ $1 == 'f' ]] && reboot
	totally_failed_count=$[ totally_failed_count + 1 ]
	[[ $totally_failed_count -eq 3 ]] && reboot
}

partly_auth(){
	while [[ 0 -eq 0 ]]; do
		auth_result
		[[ $? -eq 2 ]] && clean_work
		[[ $[ auth_count - totally_failed_count ] -eq 3 ]] && reboot_logic 'f'
	done
}

user_auth(){
	auth_count=$[ auth_count + 1 ]
	write2log 3 "AUTH $auth_count PROCESS"
	for (( k = 0; k < ${#result[@]}; k++ )); do
		triple_auth $k
	done
}

auth_result(){
	reset_network && user_auth
	flag=0
	for data in ${result[@]}; do
		[[ ${data} -eq 1 ]] && flag=$[ flag + 1 ]
	done
	[[ $flag -eq 0 ]] && return 1
	[[ $flag -eq 4 ]] && return 2
	return 3
}

auth_logic(){
	auth_result
	tmp=$?
	[[ $tmp -eq 1 ]] && reboot_logic && return
	[[ $tmp -eq 2 ]] && clean_work
	[[ $tmp -eq 3 ]] && partly_auth
}

# Maintain func
maintain_func(){
	while [[ 0 -eq 0 ]]; do
		sleep ${interval[1]}
		is_connected
		[[ $? -eq 2 ]] && main_func
	done
}

# Main Func.
main_func(){
	initial_work
	while [[ "" == "" ]]; do
		auth_logic
		sleep ${interval[2]}
	done
}

main_func