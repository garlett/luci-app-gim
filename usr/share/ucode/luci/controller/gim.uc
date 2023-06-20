// 'use strict';

// this api receives timestamp interval THEN replys with the log of each local ip

import { open, lsdir, basename  } from 'fs';

ram_fs = "/tmp/gim/";
flash_fs = "/mnt/emmc/gim/";

function log_http(alog, abegin, aend){	// open 'alog' and output to http the traffic between 'abegin' and 'aend'
	
	const fd = open( alog );
	buff = "";
	len = 4096;
	lines = [""];
	
	while( len == 4096 ){
		buff += fd.read(4096);
		len = length(buff);
		lines = split(buff, "\n" );
		if( len == 4096 ) buff = pop(lines);

		for( i = 0; i < length(lines); i++){
			line = lines[i];
			if( substr(line, 0, 2) == "ts"  &&  substr(line, 3) >= abegin ) alog = "";
			if( substr(line, 0, 2) == "ts"  &&  substr(line, 3) >= aend ) return;
			if( alog == "" ) http.write( '"' + line + '",' );
		}
	}
	fd.close();
}

return {
	action_getts: function(args) {

		args =  split(args, "-");
		abegin = args[0];
		aend = args[1];
		last_ip = "";
		http.prepare_content('application/json');
 		http.write('{"data": [');

	// build ip_mac file list from txt ram and gz flash.
		logs = map( lsdir( ram_fs ), function(a){ return a + "." + timelocal(localtime()) + ".txt" } ); 
		push(logs, ...lsdir( flash_fs ) );
		logs = sort(logs);
		
		for(log in logs){
			fn = split(log, "."); // ip__mac.ts.gz
			
			if( fn[1] >= abegin - 86400 && fn[1] < aend ){

				if( fn[0] != last_ip ){
					if( last_ip != "" ) http.write( '""], ' );	// close log vector
					http.write( '"' + fn[0] + '", [' );		// close ip_mac string
					last_ip = fn[0];
				}

				if( fn[2] == "gz" ){
					system( "gzip -kcd " + flash_fs + log + " > /tmp/gim.tmp" );
					log_http( "/tmp/gim.tmp", abegin, aend );
					system( "rm /tmp/gim.tmp" );
				} else {
					log_http( ram_fs + fn[0], abegin, aend );
				}
			}
		}
		http.write('""]]}');
	}
}
