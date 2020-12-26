#!/bin/bash
#--------------------------
# jia2f adalah custom IDS/IPS yang dapat mengantisipasi ancaman dari potensi attacker
# seperti penggunaan ping-flood, port scan, serta failure-attempt pada service seperti SSH
#--------------------------
# o PRE-REQUESITES CHECK
#--------------------------
pkg_arr=("tcpdump" "debconf-utils" "iptables" "netfilter-persistent" "ufw" "rsyslog" "jq")
pth_arr=("log" "source" "log/.fetch")
arr_len=${#pth_arr[@]}
echo -ne "[WAIT]: Preparing internal directory ... "
for i in `seq 0 $arr_len`; do echo -ne "[$i/$arr_len]"'\r\t\t\t\t\t '; sleep 1; done;
for idx in ${pth_arr[@]}
do
	if [[ ! -d $idx ]]
	then
		mkdir $idx
	fi
done

touch "log/.fetch/.log.md5"
touch "log/.fetch/.json.md5"
touch "log/.fetch/.rules.md5"
touch "log/.fetch/.tmp.rules"
touch "log/.fetch/.load.rules"

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

arr_len=${#pkg_arr[@]}
echo -ne "\n[WAIT]: Checking required packages ...  "

i=0
echo -ne " [$i/$arr_len]"'\r\t\t\t\t\t'; sleep 1;
wait $!
for idx in ${pkg_arr[@]}
do
	i=$((++i))
	pkg_stat=$(dpkg-query -l $idx | tail -n 1 | tr -s '\t' ' ' | cut -d ' ' -f 1 2> /dev/null)
	if [[ $pkg_stat == 'ii' ]]
	then
		echo -ne " [$i/$arr_len]"'\r\t\t\t\t\t'; sleep 1;
		continue
	fi
	nohup sudo apt-get install $idx -y &> /dev/null &
	wait $!
		echo -ne " [$i/$arr_len]"'\r\t\t\t\t\t'; sleep 1;
done

rules_check=$(sudo iptables -L -n -v | grep UNCLE)
if [[ $rules_check == '' ]]
then
	sudo iptables -I INPUT -p icmp --icmp-type echo-request -j LOG --log-prefix "LOGGING_PING_UNCLESURV"
fi

curr_md5=$(md5sum "setup.json" | cut -d ' ' -f 1)
load_md5=$(cat "log/.fetch/.json.md5")


echo -ne "\n[WAIT]: Loading recent iptables rules ..."; sleep 1;
nohup sudo service netfilter-persistent restart &> /dev/null &
wait $!
if [[ -s "log/.fetch/.load.rules" ]]
then
	uniq_rules=$(sudo cat log/.fetch/.load.rules | sort | uniq)
	cat /dev/null > "log/.fetch/.load.rules"
	echo "$uniq_rules" > "log/.fetch/.load.rules"
fi
if [[ -s "log/.fetch/.load.rules" ]]
then
	while IFS= read -r get_line
	do
		if [[ $get_line ]]
		then		
			IFS=$'\t'
			read -a arr_rule <<< "$get_line"
			if [[ ${#arr_rule[@]} -gt 3 ]]
			then
				check_rule=$(sudo iptables -S INPUT | grep "${arr_rule[0]}" | grep "${arr_rule[1]}" | grep "${arr_rule[4]}")
				if [[ ! $check_rule ]]
				then
					sudo iptables -A INPUT -s ${arr_rule[0]} -p ${arr_rule[1]}  --dport ${arr_rule[4]} -m conntrack --ctstate NEW,ESTABLISHED -j ${arr_rule[2]}
					#sudo iptables -A INPUT -s $i_src -p $i_ptc --dport $p_tcp -m conntrack --ctstate NEW,ESTABLISHED -j $rule_param
				fi					
			else
				check_rule=$(sudo iptables -S INPUT | grep "${arr_rule[0]}" | grep "${arr_rule[1]}")
				if [[ ! $check_rule ]]
				then
					sudo iptables -A INPUT -s ${arr_rule[0]} -p ${arr_rule[1]} -j ${arr_rule[2]}
				fi
			fi
		fi
	done < "log/.fetch/.load.rules"
fi

echo -ne "\n[WAIT]: Restarting rsyslog daemon ..."; sleep 1;
nohup sudo service rsyslog restart &> /dev/null &
wait $!

#echo -ne "\n[WAIT]: Enabling firewall ..."
#ufw_check=$(sudo ufw verbose | cut -d ':' -f 2 | tr -d ' ')
#if [[ $ufw_check == 'inactive' ]]
#then
#	nohup sudo ufw enable &> /dev/null &
#fi

### allow outbound ip
### baca file DB, buat load reload