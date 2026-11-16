// =============================================================================
// PARTE 1 (Grafo) - Manipulação e Inserção de Dados
// Sistema de recomendações de e-commerce em Neo4j
//
// Como executar:
//   cypher-shell -u neo4j -p <senha> -f 01_modelo_grafo.cypher
// ou copie e cole no Neo4j Browser.
//
// MODELO
//   Nós:            (:Usuario {id, nome, cidade})
//                   (:Produto {id, nome, categoria, preco})
//   Relacionamentos (:Usuario)-[:AMIGO_DE]->(:Usuario)
//                   (:Usuario)-[:COMPROU {quantidade, data}]->(:Produto)
//
// AMIGO_DE é gravado em uma única direção, mas a amizade é mútua:
// nas consultas usamos -[:AMIGO_DE]- (sem seta) para ignorar a direção.
//
// O script usa MERGE, então pode ser executado várias vezes sem duplicar dados.
// =============================================================================

// ---- Restrições de unicidade (também criam índice em Usuario.id e Produto.id) ----
CREATE CONSTRAINT usuario_id_unico IF NOT EXISTS FOR (u:Usuario) REQUIRE u.id IS UNIQUE;
CREATE CONSTRAINT produto_id_unico IF NOT EXISTS FOR (p:Produto) REQUIRE p.id IS UNIQUE;

// ---- Nós do tipo Usuario ----
UNWIND [
  {id: 'u1', nome: 'Ana',   cidade: 'São Luís'},
  {id: 'u2', nome: 'Bruno', cidade: 'São Luís'},
  {id: 'u3', nome: 'Carla', cidade: 'Imperatriz'},
  {id: 'u4', nome: 'Diego', cidade: 'São Luís'},
  {id: 'u5', nome: 'Elisa', cidade: 'Imperatriz'},
  {id: 'u6', nome: 'Fábio', cidade: 'Caxias'},
  {id: 'u7', nome: 'Gabi',  cidade: 'Caxias'},
  {id: 'u8', nome: 'Hugo',  cidade: 'São Luís'}
] AS dado
MERGE (u:Usuario {id: dado.id})
SET u.nome = dado.nome, u.cidade = dado.cidade;

// ---- Nós do tipo Produto ----
UNWIND [
  {id: 'p1', nome: 'Notebook Ultra 14',     categoria: 'computadores', preco: 4599.00},
  {id: 'p2', nome: 'Mouse Sem Fio',         categoria: 'perifericos',  preco: 79.90},
  {id: 'p3', nome: 'Teclado Mecânico',      categoria: 'perifericos',  preco: 289.90},
  {id: 'p4', nome: 'Monitor 27 polegadas',  categoria: 'monitores',    preco: 1199.00},
  {id: 'p5', nome: 'Headset Gamer',         categoria: 'audio',        preco: 249.90},
  {id: 'p6', nome: 'Webcam Full HD',        categoria: 'perifericos',  preco: 159.90}
] AS dado
MERGE (p:Produto {id: dado.id})
SET p.nome = dado.nome, p.categoria = dado.categoria, p.preco = dado.preco;

// ---- Relacionamentos AMIGO_DE ----
// Rede: Ana - Bruno - Diego - Fábio - Gabi - Hugo, e Ana - Carla - Elisa - Gabi
UNWIND [
  ['u1', 'u2'], ['u1', 'u3'],
  ['u2', 'u4'], ['u3', 'u5'],
  ['u4', 'u6'], ['u5', 'u7'],
  ['u6', 'u7'], ['u7', 'u8']
] AS par
MATCH (a:Usuario {id: par[0]}), (b:Usuario {id: par[1]})
MERGE (a)-[:AMIGO_DE]->(b);

// ---- Relacionamentos COMPROU (com propriedades na aresta) ----
UNWIND [
  {u: 'u1', p: 'p2', qtd: 1, data: '2026-09-10'},
  {u: 'u1', p: 'p3', qtd: 1, data: '2026-09-10'},
  {u: 'u2', p: 'p2', qtd: 2, data: '2026-09-15'},
  {u: 'u2', p: 'p3', qtd: 1, data: '2026-09-15'},
  {u: 'u2', p: 'p5', qtd: 1, data: '2026-10-01'},
  {u: 'u3', p: 'p3', qtd: 1, data: '2026-09-20'},
  {u: 'u3', p: 'p4', qtd: 1, data: '2026-10-05'},
  {u: 'u4', p: 'p1', qtd: 1, data: '2026-09-25'},
  {u: 'u4', p: 'p2', qtd: 1, data: '2026-09-25'},
  {u: 'u4', p: 'p4', qtd: 1, data: '2026-10-12'},
  {u: 'u5', p: 'p1', qtd: 1, data: '2026-10-02'},
  {u: 'u5', p: 'p4', qtd: 1, data: '2026-10-02'},
  {u: 'u5', p: 'p5', qtd: 1, data: '2026-10-20'},
  {u: 'u6', p: 'p1', qtd: 1, data: '2026-10-08'},
  {u: 'u6', p: 'p6', qtd: 1, data: '2026-10-08'},
  {u: 'u7', p: 'p5', qtd: 1, data: '2026-10-15'},
  {u: 'u7', p: 'p6', qtd: 1, data: '2026-10-15'},
  {u: 'u8', p: 'p1', qtd: 1, data: '2026-10-22'},
  {u: 'u8', p: 'p4', qtd: 1, data: '2026-10-22'}
] AS compra
MATCH (u:Usuario {id: compra.u}), (p:Produto {id: compra.p})
MERGE (u)-[c:COMPROU]->(p)
SET c.quantidade = compra.qtd, c.data = date(compra.data);

// ---- Conferência: contagem por tipo de nó e de relacionamento ----
// Esperado: 8 usuários, 6 produtos, 8 AMIGO_DE e 19 COMPROU.
MATCH (u:Usuario) RETURN 'Usuario' AS tipo, count(u) AS total
UNION ALL
MATCH (p:Produto) RETURN 'Produto' AS tipo, count(p) AS total
UNION ALL
MATCH ()-[r:AMIGO_DE]->() RETURN 'AMIGO_DE' AS tipo, count(r) AS total
UNION ALL
MATCH ()-[r:COMPROU]->() RETURN 'COMPROU' AS tipo, count(r) AS total;
