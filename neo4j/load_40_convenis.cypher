// Create Agreements
// Dataset: "Registration of Collaboration and Cooperation Agreements"

// URL: https://analisi.transparenciacatalunya.cat/Sector-P-blic/Registre-de-Convenis-de-Col-laboraci-i-Cooperaci-/exh2-diuf/about_data

// Delete Agreements
// match (n:Agreement) detach delete (n);

CREATE CONSTRAINT agreement_code IF NOT EXISTS FOR (n:Agreement) REQUIRE n.code IS UNIQUE;
CREATE TEXT INDEX AgreementCodeText IF NOT EXISTS FOR (n:Agreement) ON (n.code);
CREATE TEXT INDEX AgreementTitleText IF NOT EXISTS FOR (n:Agreement) ON (n.title);

// Load Agreement
load csv with headers from 'file:///convenis.csv' as r
with 
    r["Any de signatura"] as year,
    r["Matèria"] as subject,
    r["Codi Secció"] as section_code,
    r["Secció"] as section_name,
    r["Número Conveni Definitiu"] as code,
    r["Títol Conveni"] as title,
    r["Convenis Relacionats"] as linked_agreements,
    split(r["Data Signatura"],"/") as signature_date,
    split(r["Data Vigència"],"/") as validity_date,
    r["Durada"] as duration,
    r["Vigent"] as is_current,
    r["Prorrogable"] as is_extendable,
    r["Objecte"] as object,
    r["Drets i obligacions"] as commitments,
    r["Compliment i execució"] as complaince_and_execution,
    r["Organismes signants per part de la Generalitat"] as signees_gencat,
    r["Organismes Signants Ens Locals"] as signees_local,
    r["Codi AOC Organismes Signants Ens Locals"] as signees_local_code,
    r["Altres Organismes Signants"] as signees_other,
    r["Total aportacions previstes Generalitat"] as contributions_gencat,
    r["Total aportacions previstes Ens Locals"] as contributions_local,
    r["Total aportacions previstes Altres Organismes"] as contributions_other,
    r["Sumatori aportacions totals previstes"] as contributions_total,
    r["Descàrrega PDF conveni"] as agreement_document_link,
    r["Descàrrega altres documents"] as other_documents_link

// where code is not null
where code =~'(2022/9/030.*)|(202[2|4]/8/00.*)'
with * limit 200
merge (a:Agreement {code: code})
// on create
set 
    a.title = title,
    a.signature_date = date({day:tointeger(signature_date[0]),month:tointeger(signature_date[1]),year:tointeger(signature_date[2])}),
    a.validity_date = date({day:tointeger(validity_date[0]),month:tointeger(validity_date[1]),year:tointeger(validity_date[2])}),
    a.subject = subject,
//    a.linked_agreements = linked_agreements,
    a.document = agreement_document_link
set a.signees_gencat = signees_gencat,
    a.signees_local = signees_local,
    a.signees_other = signees_other,
a.linked_agreements = null
;


// Create the :LINKED_TO relationship for the linked agreements

load csv with headers from 'file:///convenis.csv' as r

with
    r["Número Conveni Definitiu"] as code,
    r["Convenis Relacionats"] as linked_agreements

where code =~'(2022/9/030.*)|(202[2|4]/8/00.*)'
    and linked_agreements is not null
unwind split(linked_agreements,";") as pk
match (a1:Agreement {code: code})
match (a2:Agreement {code: trim(pk)})
merge (a1)-[l:LINKED_TO]-(a2)
;