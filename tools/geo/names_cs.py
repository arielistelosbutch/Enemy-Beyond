# Czech names of the countries as of spring 1990 (Projekt X starts 24. 4. 1990).
# Several of today's countries are one 1990 country: the key is today's ISO code.
SU = "AM AZ BY EE GE KG KZ LT LV MD RU TJ TM UA UZ".split()
YU = "BA HR ME MK RS SI XK".split()
NAMES = {
 "AD":"Andorra","AE":"Spojené arabské emiráty","AF":"Afghánistán","AG":"Karibik","AI":"Karibik","AL":"Albánie","AO":"Angola",
 "AQ":"Antarktida","AR":"Argentina","AS":"Tichomoří","AT":"Rakousko","AU":"Austrálie","AW":"Karibik","AX":"Finsko","BB":"Karibik",
 "BD":"Bangladéš","BE":"Belgie","BF":"Burkina Faso","BG":"Bulharsko","BH":"Bahrajn","BI":"Burundi","BJ":"Benin","BL":"Karibik",
 "BM":"Bermudy","BN":"Brunej","BO":"Bolívie","BQ":"Karibik","BR":"Brazílie","BS":"Bahamy","BT":"Bhútán","BW":"Botswana","BZ":"Belize",
 "CA":"Kanada","CC":"Indický oceán","CD":"Zair","CF":"Středoafrická republika","CG":"Kongo","CH":"Švýcarsko","CI":"Pobřeží slonoviny",
 "CK":"Tichomoří","CL":"Chile","CM":"Kamerun","CN":"Čína","CO":"Kolumbie","CR":"Kostarika","CU":"Kuba","CV":"Kapverdy","CW":"Karibik",
 "CX":"Indický oceán","CY":"Kypr","CZ":"Československo","DE":"Německo","DJ":"Džibutsko","DK":"Dánsko","DM":"Karibik","DO":"Dominikánská republika",
 "DZ":"Alžírsko","EC":"Ekvádor","EG":"Egypt","EH":"Západní Sahara","ER":"Etiopie","ES":"Španělsko","ET":"Etiopie","FI":"Finsko",
 "FJ":"Fidži","FK":"Falklandy","FM":"Tichomoří","FO":"Faerské ostrovy","FR":"Francie","GA":"Gabon","GB":"Velká Británie","GD":"Karibik",
 "GF":"Francouzská Guyana","GG":"Velká Británie","GH":"Ghana","GI":"Gibraltar","GL":"Grónsko","GM":"Gambie","GN":"Guinea","GP":"Karibik",
 "GQ":"Rovníková Guinea","GR":"Řecko","GS":"Jižní Georgie","GT":"Guatemala","GU":"Tichomoří","GW":"Guinea-Bissau","GY":"Guyana","HK":"Hongkong",
 "HN":"Honduras","HT":"Haiti","HU":"Maďarsko","ID":"Indonésie","IE":"Irsko","IL":"Izrael","IM":"Velká Británie","IN":"Indie","IQ":"Irák",
 "IR":"Írán","IS":"Island","IT":"Itálie","JE":"Velká Británie","JM":"Jamajka","JO":"Jordánsko","JP":"Japonsko","KE":"Keňa","KH":"Kambodža",
 "KI":"Tichomoří","KM":"Komory","KN":"Karibik","KP":"Severní Korea","KR":"Jižní Korea","KW":"Kuvajt","KY":"Karibik","LA":"Laos","LB":"Libanon",
 "LC":"Karibik","LI":"Lichtenštejnsko","LK":"Srí Lanka","LR":"Libérie","LS":"Lesotho","LU":"Lucembursko","LY":"Libye","MA":"Maroko",
 "MC":"Monako","MF":"Karibik","MG":"Madagaskar","MH":"Tichomoří","ML":"Mali","MM":"Barma","MN":"Mongolsko","MO":"Macao","MP":"Tichomoří",
 "MQ":"Karibik","MR":"Mauritánie","MS":"Karibik","MT":"Malta","MU":"Mauricius","MV":"Maledivy","MW":"Malawi","MX":"Mexiko","MY":"Malajsie",
 "MZ":"Mosambik","NA":"Namibie","NC":"Nová Kaledonie","NE":"Niger","NF":"Tichomoří","NG":"Nigérie","NI":"Nikaragua","NL":"Nizozemsko",
 "NO":"Norsko","NP":"Nepál","NR":"Tichomoří","NU":"Tichomoří","NZ":"Nový Zéland","OM":"Omán","PA":"Panama","PE":"Peru","PF":"Tichomoří",
 "PG":"Papua Nová Guinea","PH":"Filipíny","PK":"Pákistán","PL":"Polsko","PM":"Kanada","PN":"Tichomoří","PR":"Portoriko","PS":"Palestina",
 "PT":"Portugalsko","PW":"Tichomoří","PY":"Paraguay","QA":"Katar","RE":"Indický oceán","RO":"Rumunsko","RW":"Rwanda","SA":"Saúdská Arábie",
 "SB":"Šalamounovy ostrovy","SC":"Seychely","SD":"Súdán","SE":"Švédsko","SG":"Singapur","SH":"Svatá Helena","SJ":"Špicberky","SK":"Československo",
 "SL":"Sierra Leone","SM":"Itálie","SN":"Senegal","SO":"Somálsko","SR":"Surinam","SS":"Súdán","ST":"Svatý Tomáš","SV":"Salvador","SX":"Karibik",
 "SY":"Sýrie","SZ":"Svazijsko","TC":"Karibik","TD":"Čad","TF":"Indický oceán","TG":"Togo","TH":"Thajsko","TK":"Tichomoří","TL":"Indonésie",
 "TN":"Tunisko","TO":"Tichomoří","TR":"Turecko","TT":"Karibik","TV":"Tichomoří","TW":"Tchaj-wan","TZ":"Tanzanie","UG":"Uganda",
 "US":"USA","UY":"Uruguay","VA":"Itálie","VC":"Karibik","VE":"Venezuela","VG":"Karibik","VI":"Karibik","VN":"Vietnam","VU":"Tichomoří",
 "WF":"Tichomoří","WS":"Tichomoří","YE":"Jemen","YT":"Indický oceán","ZA":"Jižní Afrika","ZM":"Zambie","ZW":"Zimbabwe",
}
for c in SU: NAMES[c] = "SSSR"
for c in YU: NAMES[c] = "Jugoslávie"
# the two Germanies (admin1 of the former GDR)
GDR = {"Brandenburg", "Mecklenburg-Vorpommern", "Saxony", "Saxony-Anhalt", "Thuringia", "Berlin", "Land Berlin"}
