// Agenda CSV (Create Events, Groups and Persons)
// Dataset: Public agenda with interest groups of senior officials and management personnel; deputy directors and similar positions of the Generalitat de Catalunya
// URL: https://analisi.transparenciacatalunya.cat/Sector-P-blic/Agenda-p-blica-amb-grups-d-inter-s-dels-alts-c-rre/hd8k-y28e/about_data

// match (n:Event) detach delete(n);

create index EventPK IF NOT EXISTS FOR (e:Event) ON (e.subject, e.date, e.time);

load csv with headers from 'file:///agenda.csv' as r
with r,split(r["Id"],"-") as id,split(r["Data"]," ") as da
with r,da,r["Data"] as data,r["Tema"] as tema
with *,split(da[0],"/") as d, split(da[1],":") as t,da[2] as ampm
with *, case when ampm="PM" and t[0]<>"12" then 12 else 0 end as hoffset
with *,data, datetime({year:tointeger(d[2]),
    month:tointeger(d[1]),day:tointeger(d[0]),
    hour:tointeger(t[0]) + hoffset,minute:tointeger(t[1]),
    timezone:"Europe/Madrid"})
    as date, tema
with *, date(date) as dia,localtime(date) as hora


with *,trim(r["Grup d'interès"]) as gname,
    trim(replace(r['Nom i cognoms'],' i ',' ')) as nomcognoms


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


match (o:Organization {pk: unitat_pk})

// Create event
merge(e:Event {subject:tema, date:dia, time:hora })  

// Link Organization
merge (o)-[:PARTICIPATE]->(e)


// Link "Grup d'interes" 
// Grup d'interes can also be a Department or an Organization

// TODO complete rename old dept names
with *,
case gname
when "Departament d'Ensenyament" then "Departament d'Educació"
// DECRET 21/2021
when "Departament de Territori i Sostenibilitat" then "Departament de Polítiques Digitals i Territori"
when "Departament d'Empresa i Coneixement" then "Departament d'Empresa i Treball"
when "Departament d'Agricultura, Ramaderia, Pesca i Alimentació" then "Departament d'Acció Climàtica, Alimentació i Agenda Rural"
when "Departament d'Acció Exterior, Relacions Institucionals i Transparència" then "Departament d'Acció Exterior i Transparència"
when "Departament de Treball, Afers Socials i Famílies" then "Departament de Drets Socials"
when "Departament de Treball, Afers Socials i Familia" then "Departament de Drets Socials"
when "Departament de Polítiques Digitals i Administració Pública" then "Departament de Polítiques Digitals i Territori"
when "Departament Polítiques Digitals i Administració Pública" then "Departament de Polítiques Digitals i Territori"
when "Consell de Treball, Econòmic i Social de Catalunya" then "Departament d'Empresa i Treball"
else gname
end as gname


with *
optional match (o2:Organization {name: gname})
foreach (o3 in case when o2 is null then [] else [o2] end | merge (o3)-[:PARTICIPATE]->(e))
with *,case when o2 is null then [1] else [] end as make_group
FOREACH ( id IN make_group | 
    MERGE (g:Group {pk: apoc.text.clean(gname)})
        on create set g.name = gname
        set g.has_events = true
    merge (g)-[ge:PARTICIPATE]->(e)
)


// Link Person
merge(p:Person {pk: apoc.text.clean(nomcognoms)})
on create set p.name = nomcognoms

merge (p)-[pa:PARTICIPATE]->(e)
set pa.role=trim(r['Càrrec'])
;
