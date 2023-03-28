-- Criando esquema
DROP SCHEMA IF EXISTS BridgeStore CASCADE;
CREATE SCHEMA BridgeStore;
SET search_path = BridgeStore;

-- Criando tabela Categoria
CREATE TABLE Categoria (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(50) NOT NULL
);

-- Criando tabela Produto
CREATE TABLE Produto (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    preco NUMERIC(10,2) NOT NULL,
    quantidade_estoque INTEGER NOT NULL,
    id_categoria INTEGER NOT NULL,
    FOREIGN KEY (id_categoria) REFERENCES Categoria (id)
);

-- Criando tabela Cliente
CREATE TABLE Cliente (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    cpf CHAR(11) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    sexo VARCHAR(10) NOT NULL
);

-- Criando tabela Pedido
CREATE TABLE Pedido (
    id SERIAL PRIMARY KEY,
    data_pedido DATE NOT NULL,
    endereco_entrega VARCHAR(200) NOT NULL,
    id_cliente INTEGER NOT NULL,
    total_compra DECIMAL(10,2),
    pagamento VARCHAR(20),
    FOREIGN KEY (id_cliente) REFERENCES Cliente (id)
    
);

-- Criando tabela ItemPedido
CREATE TABLE ItemPedido (
    id_pedido INTEGER NOT NULL,
    id_produto INTEGER NOT NULL,
    quantidade INTEGER NOT NULL,
    preco_unitario DECIMAL(10,2),
    PRIMARY KEY (id_pedido, id_produto),
    FOREIGN KEY (id_pedido) REFERENCES Pedido (id),
    FOREIGN KEY (id_produto) REFERENCES Produto (id)
);

BEGIN;
SET CONSTRAINTS ALL DEFERRED;

-- Inserindo 50 categorias
INSERT INTO Categoria (nome)
SELECT md5(random()::text)
FROM generate_series(1,50);

-- Inserindo 50 produtos
INSERT INTO Produto (nome, descricao, preco, quantidade_estoque, id_categoria)
SELECT CONCAT('Produto ', generate_series), md5(random()::text) as descricao, (random() * 100)::numeric(10,2), floor(random() * 1000), floor(random() * 50) + 1
FROM generate_series(1,50);

-- Inserindo 50 clientes
INSERT INTO Cliente (nome, cpf, email, sexo)
SELECT 
    md5(random()::text), -- gerando nome aleatório
    LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 11, '0'), -- gerando CPF aleatório de 11 digitos
    CONCAT(md5(random()::text), 
           CASE 
               WHEN random() < 0.5 THEN '@gmail.com'
               ELSE '@outlook.com'
           END), -- gerando email aleatório
    CASE
        WHEN random() < 0.4 THEN 'masculino'
        WHEN random() < 0.8 THEN 'feminino'
        ELSE 'indefinido'
    END -- gerando sexo aleatório
FROM generate_series(1, 50);

-- Inserindo 50 pedidos
INSERT INTO Pedido (data_pedido, endereco_entrega, id_cliente)
SELECT CURRENT_DATE - INTERVAL '1 day' * floor(random() * 365), md5(random()::text), floor(random() * 50) + 1
FROM generate_series(1,50);

-- Inserindo 50 itens de pedido
INSERT INTO ItemPedido (id_pedido, id_produto, quantidade, preco_unitario)
SELECT p.id, pr.id, floor(random() * 10 + 1), pr.preco
FROM (
    SELECT id
    FROM Pedido
    ORDER BY random()
    LIMIT 50
) p
CROSS JOIN (
    SELECT id, preco
    FROM Produto
    ORDER BY random()
    LIMIT 50
) pr
LEFT JOIN ItemPedido ip ON ip.id_pedido = p.id AND ip.id_produto = pr.id
WHERE ip.id_pedido IS NULL;

-- Adicionando o campo valor_total na tabela ItemPedido
ALTER TABLE ItemPedido ADD COLUMN valor_total DECIMAL(10,2);

-- Atualizando o valor_total na tabela ItemPedido
UPDATE ItemPedido SET valor_total = quantidade * preco_unitario;

-- Atualizando o total_compra na tabela Pedido
UPDATE Pedido SET total_compra = (
    SELECT COALESCE(SUM(valor_total), 0)
    FROM ItemPedido
    WHERE id_pedido = Pedido.id
);

-- Atualizando o campo pagamento na tabela Pedido
UPDATE Pedido SET pagamento = 
    CASE 
        WHEN random() < 0.25 THEN 'pix'
        WHEN random() < 0.5 THEN 'debito'
        WHEN random() < 0.75 THEN 'credito'
        ELSE 'boleto bancario'
    END; -- gerando método de pagamento aleatório

   
-- Adicionando o campo parcelas na tabela Pedido
ALTER TABLE Pedido ADD COLUMN parcelas VARCHAR;

-- Atualizando o valor do campo parcelas para não se aplica para os pedidos que não são pagos com cartão de crédito
UPDATE Pedido SET parcelas = 'nao se aplica' WHERE pagamento <> 'credito';

-- Atualizando o valor da coluna parcelas para um número aleatório entre 1 e 12 para os pedidos que são pagos com cartão de crédito
UPDATE Pedido SET parcelas = floor(random() * 12) + 1 WHERE pagamento = 'credito';

COMMIT;

-- Listando todos os produtos com nome, descrição e preço em ordem alfabética crescente
SELECT nome, descricao, preco
FROM Produto
ORDER BY nome ASC;

-- Listando todas as categorias com nome e número de produtos associados, em ordem alfabética crescente
SELECT c.nome, count(p.id) as num_produtos
FROM Categoria c
LEFT JOIN Produto p ON p.id_categoria = c.id
GROUP BY c.id
ORDER BY c.nome ASC;

-- Listando todos os pedidos com data, endereço de entrega e total do pedido (soma dos preços dos itens), em ordem decrescente de data
SELECT id, data_pedido, endereco_entrega, 
    (SELECT SUM(p.preco * i.quantidade) FROM ItemPedido i INNER JOIN Produto p ON i.id_produto = p.id WHERE i.id_pedido = pe.id) as total_pedido
FROM Pedido pe
ORDER BY data_pedido DESC;

-- Listando todos os produtos que já foram vendidos em pelo menos um pedido, com nome, descrição, preço e quantidade total vendida, em ordem decrescente de quantidade total vendida
SELECT p.nome, p.descricao, p.preco, SUM(ip.quantidade) AS quantidade_total_vendida
FROM Produto p
JOIN ItemPedido ip ON p.id = ip.id_produto
GROUP BY p.id
ORDER BY quantidade_total_vendida DESC;

-- Listando todos os pedidos feitos por um determinado cliente, filtrando-os por um determinado período, em ordem alfabética crescente do nome do cliente e ordem crescente da data do pedido
SELECT c.nome, p.id, p.data_pedido
FROM Cliente c
JOIN Pedido p ON c.id = p.id_cliente
WHERE c.id = 1 AND p.data_pedido BETWEEN '2022-01-01' AND '2022-12-31'
ORDER BY c.nome ASC, p.data_pedido ASC;


-- Listando possíveis produtos com nome replicado e a quantidade de replicações, em ordem decrescente de quantidade de replicações
SELECT nome, COUNT(*) as quantidade_replicacoes
FROM Produto
GROUP BY nome
HAVING COUNT(*) > 1
ORDER BY quantidade_replicacoes DESC;