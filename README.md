# Entregável Semana 09 e 12 — Grafo de Recomendações (Neo4j) e Cache de Carrinho (Redis)

Dois componentes de um e-commerce:

- **Grafo (Neo4j / Cypher):** modelo de usuários, produtos, amizades e compras para um sistema de recomendações.
- **Cache (Redis):** estrutura de chaves para o carrinho de compras, com TTL e invalidação no checkout.

## Estrutura do repositório

| Arquivo | Parte | Conteúdo |
|---|---|---|
| `01_modelo_grafo.cypher` | 1 — Grafo | Restrições, nós `Usuario` e `Produto`, relacionamentos `AMIGO_DE` e `COMPROU` |
| `02_amigos_de_amigos.cypher` | 2 — Grafo | Consulta "amigos de amigos que compraram o Produto X" |
| `03_desafio_interesses_em_comum.cypher` | 3 — Grafo | Recomendação por interesses em comum |
| `01_estrutura_chaves.redis` | 1 — Cache | Padrão de chaves e estrutura Hash do carrinho |
| `02_operacoes_carrinho.redis` | 2 — Cache | Adicionar item, ler carrinho completo, TTL |
| `03_desafio_invalidacao_cache.redis` | 3 — Cache (bônus) | Invalidação no checkout |
| `README.md` | 4 | Instruções, decisões de modelagem e reflexão |

## Como executar

**Grafo** — Neo4j 5.x em execução; rodar na ordem:

```bash
cypher-shell -u neo4j -p <senha> -f 01_modelo_grafo.cypher
cypher-shell -u neo4j -p <senha> -f 02_amigos_de_amigos.cypher
cypher-shell -u neo4j -p <senha> -f 03_desafio_interesses_em_comum.cypher
```

Também é possível colar o conteúdo no Neo4j Browser. Os scripts de criação usam `MERGE`, então podem ser
executados mais de uma vez sem duplicar dados.

**Cache** — Redis em execução em `localhost:6379`. Cada linha do arquivo é um comando; `ECHO` imprime os
títulos das etapas:

```bash
redis-cli < 01_estrutura_chaves.redis
redis-cli < 02_operacoes_carrinho.redis
redis-cli < 03_desafio_invalidacao_cache.redis
```

No PowerShell o operador `<` não existe; use `Get-Content 01_estrutura_chaves.redis | redis-cli`.

## Parte 1 — Modelo de grafo

```
(:Usuario {id, nome, cidade})  -[:AMIGO_DE]->  (:Usuario)
(:Usuario)                     -[:COMPROU {quantidade, data}]->  (:Produto {id, nome, categoria, preco})
```

- **Dois tipos de nós:** `Usuario` e `Produto`.
- **Dois tipos de relacionamentos:** `AMIGO_DE` (Usuario → Usuario) e `COMPROU` (Usuario → Produto), esta com
  as propriedades `quantidade` e `data`.
- A amizade é mútua, mas é gravada **uma vez, em uma direção**. Nas consultas usa-se `-[:AMIGO_DE]-` (sem
  seta) para ignorar a direção, evitando duplicar arestas.
- Restrições de unicidade em `Usuario.id` e `Produto.id` garantem que não existam nós repetidos e criam o
  índice usado nos `MATCH {id: ...}`.
- Massa de dados: 8 usuários, 6 produtos, 8 amizades e 19 compras. A rede de amizades foi desenhada para que
  existam amigos a 1, 2, 3 e 4 saltos de distância da usuária Ana.

### Estrutura de chaves do cache (Redis)

| Chave | Quando usar |
|---|---|
| `cart:user:{id_usuario}` | usuário logado (ex.: `cart:user:101`) |
| `cart:session:{id_sessao}` | visitante anônimo (ex.: `cart:session:a1b2c3`) |

- **Estrutura de dados: Hash.** Campo = `produto:{produto_id}`, valor = quantidade.
  Exemplo: `HSET cart:user:101 produto:99 1`.
- **Por que Hash e não uma String com JSON?** Permite alterar um único item sem ler e reescrever o carrinho
  inteiro: `HINCRBY` soma a quantidade de forma **atômica**, `HDEL` remove um item, `HLEN` conta os itens.
- O prefixo `cart:` separa o domínio, e `:user:` / `:session:` evita colisão entre os dois tipos de dono.

## Parte 2 — Consultas e operações

### Grafo: amigos de amigos que compraram o Produto X

```cypher
MATCH (eu:Usuario {id: 'u1'})-[:AMIGO_DE]-(amigo:Usuario)-[:AMIGO_DE]-(fof:Usuario),
      (fof)-[:COMPROU]->(x:Produto {id: 'p1'})
WHERE fof <> eu AND NOT (eu)-[:AMIGO_DE]-(fof)
RETURN fof.nome, collect(DISTINCT amigo.nome) AS conhecidos_em_comum
```

O padrão faz **dois saltos** por `AMIGO_DE` e depois segue `COMPROU` até o produto. As cláusulas do `WHERE`
removem a própria usuária e os amigos diretos, deixando só o segundo grau. O arquivo traz ainda uma variante
com caminho de comprimento variável (`*2..2`).

Resultado esperado: **Diego** (via Bruno) e **Elisa** (via Carla).

### Cache: carrinho com TTL

```
HSET    cart:user:101 produto:99 1      # adiciona item
HINCRBY cart:user:101 produto:99 2      # soma quantidade
HGETALL cart:user:101                   # lê o carrinho completo
EXPIRE  cart:user:101 86400             # TTL de 24 h: abandono limpa o carrinho sozinho
TTL     cart:user:101                   # segundos restantes
```

O TTL é renovado a cada interação do usuário. O arquivo também simula o abandono com um carrinho de visitante
que expira em 5 segundos.

## Parte 3 — Desafio

### Grafo: usuários que compraram o mesmo produto que você também compraram Y

A consulta (`03_desafio_interesses_em_comum.cypher`) funciona em quatro passos:

1. encontra outros usuários que compraram ao menos um produto igual ao da usuária;
2. conta quantos produtos cada um compartilha com ela;
3. coleta os produtos desses usuários que ela **ainda não comprou**;
4. ranqueia pela soma dos produtos em comum e, em caso de empate, pelo número de usuários parecidos.

Para a Ana o resultado esperado é Monitor 27 polegadas, Headset Gamer e Notebook Ultra 14, nessa ordem.

### Cache (bônus): invalidação no checkout

```
DEL cart:user:101      # (ou UNLINK, que remove em segundo plano)
```

**Estratégia:** o pedido é gravado no banco principal **primeiro**; somente depois de confirmado a chave do
carrinho é removida. Se a gravação do pedido falhar, o carrinho continua no cache e o usuário não perde os
itens. Sem a invalidação, o carrinho "ressuscitaria" depois da compra, mostrando itens já comprados. O
TTL continua como rede de segurança caso o `DEL` não seja executado.

O arquivo também mostra a mesclagem do carrinho de visitante (`cart:session:...`) ao do usuário no login,
seguida da invalidação do carrinho de sessão.

## Parte 4 — Reflexão

### Por que um banco de grafos é mais eficiente que SQL com JOINs no problema dos "amigos de amigos"?

No modelo relacional, a amizade fica em uma tabela de ligação. Cada salto na rede exige **mais um JOIN** dessa
tabela com ela mesma, e o custo de cada JOIN depende do tamanho das tabelas envolvidas:

```sql
SELECT DISTINCT u3.nome
FROM amizade a1
JOIN amizade a2  ON a2.usuario_id = a1.amigo_id
JOIN compra  c   ON c.usuario_id  = a2.amigo_id
JOIN usuario u3  ON u3.id         = a2.amigo_id
WHERE a1.usuario_id = 1 AND c.produto_id = 1;
```

Para dois saltos já são quatro tabelas; para três ou quatro saltos a consulta cresce e fica lenta, porque o
banco precisa combinar milhões de linhas e procurar as chaves pelo índice a cada etapa.

Em um banco de grafos como o Neo4j, cada nó guarda **ponteiros diretos para seus relacionamentos**
(*index-free adjacency*). Navegar de um usuário para seus amigos é seguir ponteiros, sem buscar em índice
nem calcular junções. O custo passa a depender só da **vizinhança percorrida**, e não do tamanho total dos
dados. Além disso, o Cypher descreve o padrão visualmente (`(a)-[:AMIGO_DE]-(b)-[:AMIGO_DE]-(c)`), o que
torna a consulta curta e fácil de ler, e acrescentar mais saltos é só mudar o padrão.

### Por que usar um cache em memória (Redis) para o carrinho em vez de salvar direto no banco principal?

- **Latência:** o Redis guarda tudo em memória e responde em microssegundos a milissegundos. O carrinho é lido e
  alterado a cada clique, então a experiência do usuário melhora.
- **Alívio do banco principal:** a maior parte das alterações do carrinho nunca vira compra. Mantê-las fora
  do banco principal reserva-o para dados que precisam durar, como pedidos e pagamentos.
- **Dado temporário por natureza:** o TTL (`EXPIRE`) descarta sozinho os carrinhos abandonados, sem rotinas
  de limpeza.
- **Estrutura adequada:** o Hash permite alterações atômicas por item (`HINCRBY`, `HDEL`) sem reescrever o
  carrinho inteiro.

O ponto de atenção é que a memória é volátil: por isso o pedido, que é o dado importante, é gravado no banco
principal no checkout, e só então o cache é invalidado.

## Link do repositório

https://github.com/marciowsz/EntregavelSemana9e12
