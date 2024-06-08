// Create Department, Organization and Person nodes.
// Create the CHILD_OF and RESPONSIBLE_OF relationships.
// Dataset: "Tabular organization chart of the Generalitat de Catalunya"
// URL: https://analisi.transparenciacatalunya.cat/en/Sector-P-blic/Organigrama-tabular-de-la-Generalitat-de-Catalunya/czns-gsc6/about_data

create index OrganizationPK IF NOT EXISTS FOR (n:Organization) ON (n.pk);
create index OrganizationID IF NOT EXISTS FOR (n:Organization) ON (n.id);
create index PersonPK IF NOT EXISTS FOR (n:Person) ON (n.pk);


// CSV (Create Departments)
load csv with headers from 'file:///org.csv' as r
with r,case r.CODIDEP 
when "ATC" then "ECF"
when "SOC" then "EMO"
else r.CODIDEP 
end as codidep
where not toInteger(r.ID) in [20912,13571]
and trim(r.DEP)=~"Departament.*"
with distinct  tointeger(r.IDDEP) as iddep,trim(r.DEP) as dep, apoc.text.clean(r.DEP) as pk,codidep
order by iddep
merge (d:Department:Organization {id: iddep})
set d.name = dep, d.code= codidep, d.pk = pk;



// CSV (Create Organization) 
load csv with headers from 'file:///org.csv' as r

with r,case r.CODIDEP 
when "ATC" then "ECF"
when "SOC" then "EMO"
else r.CODIDEP 
end as codidep,
case trim(r.NOM)
when "Institut Català de Finances (ICF)" then "Institut Català de Finances"
else trim(r.NOM) end as nom
where not toInteger(r.ID) in [20912,13571]
and not (r.ID = r.IDDEP and trim(r.DEP)=~"Departament.*")
with distinct  tointeger(r.ID) as id,nom as nom,
    r.IDPARE as idpare, tointeger(r.IDDEP) as iddep,
    codidep + ":" +  apoc.text.clean(r.NOM) as pk
merge (o:Organization {id: id})
on create 
    set o.name = nom,o.pk = pk;


// CSV (Create CHILD_OF) 
load csv with headers from 'file:///org.csv' as r
with distinct  tointeger(r.ID) as id,tointeger(r.IDPARE) as idpare
match (child:Organization {id: id})
match (parent:Organization {id: idpare})
with child, parent
merge (child)-[r:CHILD_OF]->(parent);


// CSV (Create Person)
load csv with headers from 'file:///org.csv' as r
with r, 
    date(apoc.date.convertFormat(r["DATA MODIFICACIO"],'dd/MM/yyyy')) as data,
    trim(replace(r.RESP," i "," ")) as personName,
    apoc.text.clean(replace(r.RESP," i "," ")) as pk,
    coalesce(trim(r.CARREC),"Responsable") as roleName
where r.RESP is not null 

match (o:Organization {id: tointeger(r.ID)})
merge (p:Person {pk:pk})
on create
    set p.name = personName
merge (p)-[re:RESPONSIBLE_OF {role: roleName}]->(o)
set re.date = data;