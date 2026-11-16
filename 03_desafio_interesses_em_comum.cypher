// =============================================================================
// PARTE 3 (Grafo) - Desafio: recomendação por interesses em comum
// ("usuários que compraram o mesmo produto que você também compraram Y")
// Pré-requisito: ter executado 01_modelo_grafo.cypher
//
// Como executar:
//   cypher-shell -u neo4j -p <senha> -f 03_desafio_interesses_em_comum.cypher
//
// Para quem recomendar: Ana (u1), que comprou Mouse Sem Fio (p2) e Teclado Mecânico (p3).
//
// Passo a passo da consulta:
//   1. achar outros usuários que compraram ao menos um produto igual ao da Ana;
//   2. contar quantos produtos cada um compartilha com ela;
//   3. pegar os produtos que esses usuários compraram e que a Ana AINDA NÃO comprou;
//   4. ranquear por força da recomendação (soma dos produtos compartilhados) e,
//      em caso de empate, pelo número de usuários parecidos que compraram.
// =============================================================================

MATCH (eu:Usuario {id: 'u1'})-[:COMPROU]->(comum:Produto)<-[:COMPROU]-(outro:Usuario)
WHERE outro <> eu
WITH eu, outro, count(DISTINCT comum) AS produtos_em_comum
MATCH (outro)-[:COMPROU]->(rec:Produto)
WHERE NOT (eu)-[:COMPROU]->(rec)
RETURN rec.nome                       AS produto_recomendado,
       rec.categoria                  AS categoria,
       count(DISTINCT outro)          AS usuarios_parecidos,
       sum(produtos_em_comum)         AS forca_da_recomendacao
ORDER BY forca_da_recomendacao DESC, usuarios_parecidos DESC, produto_recomendado
LIMIT 5;

// Resultado esperado com os dados do script 01:
//   1. Monitor 27 polegadas - 2 usuários parecidos (Carla e Diego), força 2
//   2. Headset Gamer        - 1 usuário parecido (Bruno, que tem 2 produtos em comum), força 2
//   3. Notebook Ultra 14    - 1 usuário parecido (Diego), força 1
//   Webcam Full HD não aparece: ninguém que compartilha produto com a Ana a comprou.
