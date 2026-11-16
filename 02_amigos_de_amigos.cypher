// =============================================================================
// PARTE 2 (Grafo) - Mini Projeto: "amigos de amigos que compraram o Produto X"
// Pré-requisito: ter executado 01_modelo_grafo.cypher
//
// Como executar:
//   cypher-shell -u neo4j -p <senha> -f 02_amigos_de_amigos.cypher
//
// Cenário: usuária Ana (u1) quer saber quem, a dois saltos de distância
// na rede de amizades, comprou o Produto X = Notebook Ultra 14 (p1).
//
//   (Ana)-[:AMIGO_DE]-(amigo)-[:AMIGO_DE]-(amigo_de_amigo)-[:COMPROU]->(Produto X)
//
// Regras:
//   - a relação AMIGO_DE é lida sem direção (amizade mútua);
//   - o amigo de amigo não pode ser a própria Ana;
//   - o amigo de amigo não pode ser amigo direto de Ana (queremos só o 2º grau).
// =============================================================================

MATCH (eu:Usuario {id: 'u1'})-[:AMIGO_DE]-(amigo:Usuario)-[:AMIGO_DE]-(fof:Usuario),
      (fof)-[:COMPROU]->(x:Produto {id: 'p1'})
WHERE fof <> eu
  AND NOT (eu)-[:AMIGO_DE]-(fof)
RETURN fof.nome                    AS amigo_de_amigo,
       collect(DISTINCT amigo.nome) AS conhecidos_em_comum,
       x.nome                       AS produto_comprado
ORDER BY amigo_de_amigo;

// Resultado esperado com os dados do script 01:
//   Diego (via Bruno) e Elisa (via Carla).
//   Fábio e Hugo NÃO aparecem: Fábio está a 3 saltos de Ana e Hugo a 4.
//   Bruno e Carla NÃO aparecem: são amigos diretos de Ana.

// ---- Variante: usando caminho de comprimento variável (exatamente 2 saltos) ----
// Mesma lógica com a notação *2..2, útil quando o número de saltos é um parâmetro.
MATCH (eu:Usuario {id: 'u1'})-[:AMIGO_DE*2..2]-(fof:Usuario)-[:COMPROU]->(x:Produto {id: 'p1'})
WHERE fof <> eu
  AND NOT (eu)-[:AMIGO_DE]-(fof)
RETURN DISTINCT fof.nome AS amigo_de_amigo
ORDER BY amigo_de_amigo;
