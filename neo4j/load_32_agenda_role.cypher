// Agenda CSV (Create Events, Groups and Persons)
// Dataset: Public agenda with interest groups of senior officials and management personnel; deputy directors and similar positions of the Generalitat de Catalunya
// URL: https://analisi.transparenciacatalunya.cat/Sector-P-blic/Agenda-p-blica-amb-grups-d-inter-s-dels-alts-c-rre/hd8k-y28e/about_data

load csv with headers from 'file:///agenda.csv' as r
with r,split(r["Id"],"-") as id,split(r["Data"]," ") as da
with r,da,r["Data"] as data,r["Tema"] as tema
with *,split(da[0],"/") as d, split(da[1],":") as t,da[2] as ampm
with *, case when ampm="PM" and t[0]<>"12" then 12 else 0 end as hoffset
with *,data, datetime({year:tointeger(d[2]),
    month:tointeger(d[1]),day:tointeger(d[0]),
    hour:tointeger(t[0]) + hoffset,minute:tointeger(t[1]),
    timezone:"Europe/Madrid"})
    as date
with *, date(date) as dia,localtime(date) as hora,
    trim(replace(r['Nom i cognoms'],' i ',' ')) as nomcognoms,
    trim(r['Càrrec']) as role,
    apoc.text.clean(r['Càrrec']) as role_c


where dia > date('2015-01-01')

// Lookup Department code. Goverment changed the department names on various ocassion via decrees.
with *,
// DECRET 1/2018
case r.Departament
when "President de la Generalitat" then "Departament de la Presidència"
when "Departament de la Vicepresidència i d'Economia i Hisenda" then "Departament d'Economia i Hisenda"
when "Departament  de la Vicepresidència i d'Economia i Hisenda" then "Departament d'Economia i Hisenda"
when "Departament d'Afers i Relacions Institucionals i Exteriors i Transparència" then "Departament d'Acció Exterior, Relacions Institucionals i Transparència"
when "Departament de Governació, Administracions Públiques i Habitatge" then "Departament de Polítiques Digitals i Administració Pública"
else r.Departament end as name1
with *,
case name1 
when "Departament d'Ensenyament" then "Departament d'Educació"
// DECRET 21/2021
when "Departament de Territori i Sostenibilitat" then "Departament de Polítiques Digitals i Territori"
when "Departament d'Empresa i Coneixement" then "Departament d'Empresa i Treball"
when "Departament d'Agricultura, Ramaderia, Pesca i Alimentació" then "Departament d'Acció Climàtica, Alimentació i Agenda Rural"
when "Departament d'Acció Exterior, Relacions Institucionals i Transparència" then "Departament d'Acció Exterior i Transparència"
when "Departament de Treball, Afers Socials i Famílies" then "Departament de Drets Socials"
when "Departament de Polítiques Digitals i Administració Pública" then "Departament de Polítiques Digitals i Territori"
when "Departament Polítiques Digitals i Administració Pública" then "Departament de Polítiques Digitals i Territori"
when "Consell de Treball, Econòmic i Social de Catalunya" then "Departament d'Empresa i Treball"
else name1
end as name2
with *,
// DECRET 244/2021
case name2
when "Departament d'Acció Exterior i Transparència" then "Departament d'Acció Exterior i Govern Obert"
else name2
end as name3
with *,
// DECRET 184/2022
case name3
when "Departament de la Vicepresidència i de Polítiques Digitals i Territori" then "Departament de Territori"
when "Departament de Polítiques Digitals i Territori" then "Departament de Territori"
when "Departament d'Acció Exterior i Govern Obert" then "Departament d'Acció Exterior i Unió Europea"
when "Departament de Justícia" then "Departament de Justícia, Drets i Memòria"
else name3
end as deptname
match (dept:Department {name: deptname})

with *, 
    case when apoc.text.clean(r["Unitat orgànica"]) = apoc.text.clean(r.Departament) 
        then dept.pk 
        else dept.code + ":" + apoc.text.clean(r["Unitat orgànica"]) 
    end as unitat_pk



with unitat_pk,nomcognoms,
// collect(distinct role) as roles,
min(dia) as min_date, max(dia) as max_date,
//min(unitat) as unitat,count(*) as z_actes
// count(distinct role_c) as num_r,
max(role) as role
// where unitat_c contains "turisme"
// where num_r > 1
// return unitat_c,roles,role order by 1,2;

match (p:Person {pk: apoc.text.clean(nomcognoms)})
match (o:Organization {pk: unitat_pk})

merge (p)-[r:RESPONSIBLE_OF]->(o)
on create set r.role = role
set r.date_from = min_date, r.date_to = max_date
;
