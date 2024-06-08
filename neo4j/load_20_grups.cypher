// Create interest Groups nodes
// Dataset: "Register of interest groups in Catalonia"
// URL: https://analisi.transparenciacatalunya.cat/en/Legislaci-just-cia/Registre-de-grups-d-inter-s-de-Catalunya/gwpn-de62/about_data

CREATE INDEX GroupId IF NOT EXISTS FOR (g:Group) ON (g.id);
CREATE TEXT INDEX GroupName IF NOT EXISTS FOR (g:Group) ON (g.name);
CREATE TEXT INDEX GroupPK IF NOT EXISTS FOR (g:Group) ON (g.pk);

// Delete Groups
// match (n:Group) detach delete (n);

// Load Groups
load csv with headers from 'file:///grups.csv' as r
with r
where r["identificador"] is not null

merge (g:Group {id:r["identificador"]})
set g.name=r["nom"],
    g.type=r["tipus_grup"],
    g.mission=r["finalitat"],
    g.proporals=r["propostes_normatives"],
    g.url=r["pagina_web"],
    g.pk=apoc.text.clean(r.nom);
