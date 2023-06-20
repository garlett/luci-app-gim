#!/bin/sh

# IF $1 THEN stdout $1 with nslookup and human date ; config crontab ELSE
#  pop nft @gim_set
#  config/reset nft counters on @gim_set
#  convert and append @gim_set to $ram_fs/local_ip_mac
#  IF time == 0:00 THEN gzip $ram_fs to $flash_fs .ts/60

ram_fs=/tmp/gim
flash_fs=/mnt/emmc/gim

ts=$(( $(date +%s) / 60 * 60  ))
mkdir -p $ram_fs $flash_fs

# output $1 file with nslookup
[ -e "$1" ] && while read line; do
	read -r dest x << EOF
$line
EOF
	[[ "$dest" == "ts" ]] && echo "$(date -d @$x )" || echo "$dest $x $(nslookup $dest | tail -n2 | head -n1)"
done < $1


# if $1 then config to run every minute
[[ "$1" != "" ]] && ( grep -q "$0" /etc/crontabs/root || echo "* * * * * $0" >> /etc/crontabs/root )


[[ "$1" != "" ]] && exit




# check if side chain and his hook exists
log=$( nft list ruleset )
echo $log | grep -q "chain gim" || nft add chain inet fw4 gim
echo $log | grep -q "jump gim"  || nft insert rule inet fw4 forward jump gim 	#nft -a list chain inet fw4 gim > /dev/null 2>&1 || ( nft add chain inet fw4 gim   &&   nft insert rule inet fw4 forward    jump gim )


# get nft traffic log and reset counters
log=$(nft list set inet fw4 gim_set)
echo "
	flush chain inet fw4 gim
	delete set inet fw4 gim_set
	add set inet fw4 gim_set   { typeof ip saddr . ip daddr; size 65535; flags dynamic,timeout; counter; timeout 1m39s; }
	insert rule inet fw4 gim   ip saddr . ip daddr @gim_set
	insert rule inet fw4 gim   add @gim_set { ip saddr . ip daddr }
" | nft -f -


# this loop converts nft stdout to:   local_ip  dest_ip  up_down_orientation  packets  bytes
echo -e $( echo -e "${log//'elements = { '/}" | grep packets | while read line; do
	read -r src a1 dst a3 a4 pck a6 bts x << EOF
$line
EOF
	[[ "${src:0:7}" == "192.168" ]] && echo "\n$src $dst d $pck $bts" || echo "\n$dst $src u $pck $bts"
done

# this loop append ts and traffics on "$ram_fs/local_ip_mac"
) | sort | while read line; do
	read -r src dst a2 pck bts x << EOF
$line
EOF
	if [[ "$src_fn" != "$src0" ]]
	then
		src_fn=$src0
		fn=$( cat /proc/net/arp | grep "$src0 " )
		fn=${fn:41:17}
		fn=${src0//./_}__${fn//:/_}
		echo "ts $ts" >> $ram_fs/$fn
	fi
	[[ "$src" != "" ]] && [[ "$src0" == "$src" ]] && [[ "$dst0" == "$dst" ]] && echo "$dst $pck $bts $pck0 $bts0" >> $ram_fs/$fn # up/down
	src0=$src;
	dst0=$dst;
	pck0=$pck;
	bts0=$bts;
done

if [ -d $flash_fs ] && [[ "$(date +%H%M)" == "0000" ]]
then
	for fn in $ram_fs/*;
	do
		gzip $fn
		mv $fn.gz ${fn/$ram_fs/$flash_fs}.$ts.gz
	done
fi

# TODO: 
# bin: (2 bits of type [ts, dest, packets, bytes] + 14 bits of data). IF 1ts or 2dest THEN offfset from last reg ELSE raw data
