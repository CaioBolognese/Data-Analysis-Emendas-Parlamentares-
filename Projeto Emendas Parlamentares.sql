# Verificando as colunas da base de dados e entendo melhor elas.
# Quais anos estão sendo considerados ? R= 2015 até 2024
SELECT DISTINCT ano_emenda
FROM emendas_parlamentares;

# Quais são os tipos de emenda e o que eles querem dizer ? R= Temos emendas individuais (transferências), emenda do relator, emenda de bancada e emenda de comissão.
SELECT DISTINCT tipo_emenda                                # Emendas individuais são impositivas e cada parlamentar tem certo valor para indicar no orçamento.
FROM emendas_parlamentares;                                # Emendas de bancada são impositivas contudo suas indicações são feitas por deputados e senadores de um determinado estado, por exemplo.
														   # Emendas de comissão, não impositivas e são indicadas por colegiados dentro do congresso.
                                                           # Emendas do relator são as emendas referentes ao "orçamento secreto" que não exigiam os nomes dos parlamentares que eram beneficiados vigorou entre (2020 e 2022)

# Funções/Áreas a qual a emenda foi destinada, possui até mesmo subfunções que especificam o destino da emenda.
SELECT DISTINCT nome_funcao, nome_subfuncao              
FROM emendas_parlamentares;

# Têm-se os valores que foram empenhados, os que já foram liquidados e pagos no ano.
SELECT valor_empenhado, valor_liquidado, valor_pago
FROM emendas_parlamentares;
# É possível ver até a soma de todos os valores empenhados durante o período (2015-2024) que foi algo de 175 bilhões.
SELECT SUM(valor_empenhado)
FROM emendas_parlamentares;

# E por fim tem as colunas referentes aos restos a pagar nas formas de inscrito, cancelado e pago.
SELECT valor_resto_pagar_cancelado, valor_resto_pagar_inscrito ,valor_resto_pagar_pagos
FROM emendas_parlamentares;

# Estas são as colunas mais interessantes em termos de obtenção de insights e dados interessantes para uma análise.

# Data Cleaning / Tratamento dos dados - Apesar de ser uma base de dados bem pólida vale a realização de um tratamento básico para verificar qualquer incongruência.

# Como primeiro passo é recomendado nunca trabalhar na base de dados original para evitar data loss.
# Sendo assim a partir de agora as modificações serão feitas na copia da base de dados original.

SELECT *
FROM emendas_parlamentares;

CREATE TABLE emendas_copia
LIKE emendas_parlamentares;

INSERT emendas_copia
SELECT *
FROM emendas_parlamentares;

SELECT *
FROM emendas_copia;

SELECT *, # Como não há um index inato aqui criamos uma coluna nova que representará se os objetos escolhidos se repetem ou não.
ROW_NUMBER() OVER(PARTITION BY codigo_emenda) AS row_num
FROM emendas_copia;

WITH emendas_duplicatas AS 
(SELECT *,
ROW_NUMBER() OVER(PARTITION BY codigo_emenda) AS row_num
FROM emendas_copia
)
SELECT *
FROM emendas_duplicatas
WHERE row_num > 1; # Nesse CTE as observações selecionadas representam valores que contêm a variável codigo_emenda repetidas na base de dados. 
                   # Contudo vamos nos aprofundar para verificar se as outras variáveis também se repetem, como por exemplo a codigo_funcao.

WITH emendas_duplicatas AS 
(SELECT *,
ROW_NUMBER() OVER(PARTITION BY codigo_emenda, codigo_funcao) AS row_num
FROM emendas_copia
)
SELECT *
FROM emendas_duplicatas
WHERE row_num > 1; # Aqui é possível ver que ao listarmos duas variaveis não se encontram mais duplicatas. 
                   # O que é curioso pois demonstra que um mesmo codigo_emenda pode conter mais de um requerimento de verba para outra função.
                   
SELECT * 
FROM emendas_copia # Selecionando um exemplo essa mesma emenda tem 8,272 milhões destinados para educação,
WHERE codigo_emenda = 202320380007; # mais 2 milhões destinados a encargos especiais gerando um valor total de emenda de mais de 10 milhões.
									# Todavia não é comum este tipo de prática visto que poucas vezes isso ocorre dentro da nossa vasta base de dados (Por volta de 43 vezes).


# Padronização de dados
# Na coluna de sigla_uf_gasto têm-se os 26 estados e o distrito federal contudo algumas emendas estão destinadas ao território nacional e não a um estado específico e não possuem valor nessa coluna
# De modo a facilitar o acesso a essas medidas iremos nomear os elementos que possuem essa coluna faltante com a sigla BR.
SELECT DISTINCT sigla_uf_gasto
FROM emendas_copia;

SELECT *
FROM emendas_copia
WHERE localidade_gasto = 'Nacional';

# Aqui eu criei mais uma tabela para testar alguns outros comandos e evitar que algum dado fosse perdido.

UPDATE emendas_copia2
SET sigla_uf_gasto = 'BR'
WHERE localidade_gasto = 'Nacional';

SELECT *
FROM emendas_copia2
WHERE localidade_gasto = 'Nacional';

# Existem outras variáveis em localidade_gasto que também não possuem sigla pois podem ser destinadas ao exterior por exemplo neste momento não irei me compreender em traduzir todas elas. 

UPDATE emendas_copia2                      # Aqui foi realizado uma padronização nos estados que possuem o carácter 'Ã' que por algum motivo deu erro na etapa de importar a base de dados.
SET localidade_gasto = 'SÃO PAULO (UF)'    # Essa etapa de padronização foi realizada para os estados pois possuiam apenas dois que era necessário tal correção.
WHERE localidade_gasto LIKE 'SÃO PAULO';   # Contudo esse mesmo erro ocorre para os municípios o que torna a correção bem mais dificil pois o carácter ? pode representar ou 'õ' ou 'ã' logo
                                           # Somente irei realizar a correção nas colunas com o número reduzido de váriaveis.
UPDATE emendas_copia2
SET localidade_gasto = 'MARANHÃO (UF)'
WHERE localidade_gasto = 'MARANH?O (UF)';

SELECT DISTINCT nome_subfuncao
FROM emendas_copia2
WHERE nome_subfuncao LIKE '%?%';

UPDATE emendas_copia2
SET nome_subfuncao = REPLACE(nome_subfuncao, '?', 'ã')
WHERE nome_subfuncao LIKE '%?%';

UPDATE emendas_copia2
SET nome_funcao = REPLACE(nome_funcao, '?', 'ã')
WHERE nome_funcao LIKE '%?%';

SELECT DISTINCT nome_funcao
FROM emendas_copia2;

UPDATE emendas_copia2
SET nome_funcao = REPLACE(nome_funcao, 'ã', 'õ')
WHERE nome_funcao LIKE '%exte%' OR nome_funcao LIKE '%nicaç%';

# Concluindo a etapa de limpeza dos dados, a partir da próxima seção realizarei a etapa de análise dos dados.

## Data analysis / Análise dos dados 

SELECT *
FROM emendas_copia2;

SELECT MAX(valor_empenhado), MAX(valor_pago), AVG(valor_empenhado) # Vamos a priori procurar algumas emendas utilizando MAX para encontrar valores máximos dentro de uma determinada coluna
FROM emendas_copia2;                                               #  E AVG para encontrar a média dos valores empenhados com emendas.

SELECT *                                 # Assim encontramos que o valor máximo empenhado em uma determinada emenda é de 2.773.378.867 o que é um valor bem alto, sendo assim vamos procurar de que emenda estamos falando
FROM emendas_copia2                      # Com o código a seguir é possível selecionar somente ela para a análise.
WHERE valor_empenhado = 2773378867;
										 # A emenda '202181000792' se trata de uma emenda de relator proposta para a área da saúde durante o ano de 2021, tal valor exorbitante pode ser justificado como
                                         # os valores destinados a crise do COVID-19 que afetou todo o Brasil durante tal período. Contudo é pertinente destacar que tal emenda foi realizada como Emenda de Relator
                                         # Que se tratava daquelas emendas permitidas durante 2020 a 2022 onde permeavam falta de clareza sobre quem era beneficiado e para onde iria tal verba, em resumo havia pouca
                                         # Transparência sobre esse valor empenhado.
                                                                  
SELECT *                                 # Visto que esse assunto foi pertinente nas mais diversas discussões no Brasil vamos nos aprofundar nas Emendas de Relator por agora.
FROM emendas_copia2                      # Como já menciondado os anos que compreendem as Emendas de Relator são o anos de 2020 a 2022 com cerca de 274 propostas de emendas para as mais distintas áreas
WHERE tipo_emenda = 'Emenda de Relator'  # Como Saúde, Segurança Pública, Agricultura e entre outras, a maioria das localidades do gasto estão dispostas como gastos no território nacional o que destaca ainda mais 
ORDER BY ano_emenda;                     # a falta de clareza da região beneficiada com as verbas.


SELECT SUM(valor_empenhado)              # As emendas de relator somadas representam um total de '19.449.750.083,20001'. Algo em torno de 19 Bilhões e meio.                 
FROM emendas_copia2                      # Em termos percentuais representa 11,11% do total empenhado no periodo de 2015-2024 presente neste dataset.
WHERE tipo_emenda = 'Emenda de Relator';

SELECT *
FROM emendas_copia2;

SELECT sigla_uf_gasto, SUM(valor_empenhado) # Nessa query é possível ordenar os valores empenhados de emenda por estado.
FROM emendas_copia2       					# É notável o grande gasto com emendas destinadas a todo o território nacional, logo seguido por São Paulo (SP) como estado que mais arrecada valores empenhados em emendas
GROUP BY sigla_uf_gasto                     # No Brasil, fechando o top 3 com Minas Gerais (MG) e Bahia (BA).
ORDER BY 2 DESC;

SELECT ano_emenda, SUM(valor_empenhado) AS valor_gasto_ano # Separando a soma do valor empenhado por ano é notável que os gastos não seguem necessariamente um padrão de aumento
FROM emendas_copia2 									   # Na verdade para entender melhor essa variação é necessário olhar para o orçamento do ano em questão e os acontecimentos específicos do Brasil como um todo
GROUP BY ano_emenda                                        # Gerando assim disparidade dos anos se comparados lado a lado.
ORDER BY 1 ASC;

SELECT                                                     # É possível também gerar essa tabela com o total em porcentagem para melhor visualização da divisão por ano
    ano_emenda,
    SUM(valor_empenhado) AS total_empenhado_ano,
    (SUM(valor_empenhado) / (SELECT SUM(valor_empenhado) FROM emendas_copia2)) * 100 AS percentual_empenhado_ano
FROM emendas_copia2
GROUP BY ano_emenda
ORDER BY 1 ASC;

SELECT                                    # Se desejado também é possível verificar os percentuais para cada emenda de forma unitária para aquele ano o que de todo modo não é muito útil pois a referência fica muito distante
    t.ano_emenda,                         # O que de todo modo não é muito útil pois a referência fica muito distante e não clara
    t.valor_gasto_ano,                    # Mas com isso é possível verificar se existe algum outlier dentro de um determinado ano por exemplo.
    (valor_empenhado/t.valor_gasto_ano) * 100 AS percentual_empenhado
FROM emendas_copia2
JOIN (
    SELECT ano_emenda, SUM(valor_empenhado) AS valor_gasto_ano
    FROM emendas_copia2
    GROUP BY ano_emenda
) AS t ON emendas_copia2.ano_emenda = t.ano_emenda
ORDER BY percentual_empenhado DESC;

SELECT nome_funcao, SUM(valor_empenhado)   # Pode-se verificar também quais áreas tiveram o maior valor empenhado agregado, 
FROM emendas_copia2                        # Com a área da saúde ocupando o primeiro lugar seguido por encargos especiais e urbanismo.
GROUP BY nome_funcao                       # É destaque perceber como a educação ocupa somente a quarta posição nessa tabela.
ORDER BY 2 DESC;

# Irei aplicar um conceito muito presente em análises em Excel e BI que pode ser facilmente aplicado também em SQL chamado Rolling Total (Total contínuo ou acumulado).
# Utilizando a mesma query acima que separa a função a qual foi destinada a emenda e do lado o somatório dos valores para aquela função.
WITH Total_acumulado AS (
	SELECT nome_funcao, SUM(valor_empenhado) AS soma_valor_empenhado  
	FROM emendas_copia2                       
	GROUP BY nome_funcao                      
	ORDER BY 2 DESC
)
SELECT nome_funcao, soma_valor_empenhado, SUM(soma_valor_empenhado) OVER(ORDER BY nome_funcao) AS total_acumulado
FROM Total_acumulado; # Com isso é possível observar na mesma tabela a área destinada, a quantidade empenhada total e o acumulado da mesma.

# Utilizando CTE's é possível produzir tabelas bastante interessantes como a tabela a seguir:
# Nela esta presente os estados, o os valores empenhados com emendas e os anos.
# Com esses dados podemos realizar um agrupamento e criar um pequeno "Ranking" de estados com mais valor empenhado em emendas em cada ano.
WITH emendas_por_ano_por_uf (ano_emenda, estado, soma_valor_empenhado) AS (
	SELECT ano_emenda, sigla_uf_gasto, SUM(valor_empenhado)
	FROM emendas_copia2
	WHERE sigla_uf_gasto != '' AND sigla_uf_gasto != 'BR'
	GROUP BY ano_emenda, sigla_uf_gasto
    ), 
estados_rankeados_emendas AS (
	SELECT *, DENSE_RANK() OVER (PARTITION BY ano_emenda ORDER BY soma_valor_empenhado DESC) AS ranking_estados_por_emendas
    FROM emendas_por_ano_por_uf
    )
    SELECT *
    FROM estados_rankeados_emendas
    WHERE ranking_estados_por_emendas <=5 ;

# A tabela final mostra que São Paulo (SP) possui em todos os anos analisados o primeiro lugar do ranking seguido por Minas Gerais (MG),
# A partir do terceiro colocado observa-se que Bahia (BA) e Rio de Janeiro (RJ) alternam-se durante os anos
# E a quinta colocação fica sendo alternada também, pelos estados do Paraná (PR) e Rio Grande do Sul (RS).


