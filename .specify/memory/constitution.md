<!--
Sync Impact Report
- Version change: template (unversioned) → 1.0.0
- Modified principles:
  - [PRINCIPLE_1_NAME] → I. Criatividade e Inovação
  - [PRINCIPLE_2_NAME] → II. Funcionalidade e Consistência
  - [PRINCIPLE_3_NAME] → III. Estética e Experiência do Usuário
  - [PRINCIPLE_4_NAME] → IV. Integração com o Relatório
  - [PRINCIPLE_5_NAME] → V. Organização do Código e Boas Práticas
- Added sections:
  - Padrões Técnicos (R e Aplicação)
  - Fluxo de Trabalho no GitHub e Git
- Removed sections: None
- Follow-up TODOs: None
-->

# Companies Constitution

## Core Principles

### I. Criatividade e Inovação
O projeto DEVE demonstrar originalidade e inovação tanto no design visual quanto nas funcionalidades apresentadas. Soluções genéricas ou meramente reprodutivas de exemplos padrão NÃO SÃO aceitas sem diferenciação clara que agregue valor analítico ou interativo ao usuário.

### II. Funcionalidade e Consistência (NÃO NEGOCIÁVEL)
O aplicativo DEVE executar corretamente todas as operações propostas e apresentar resultados consistentes em qualquer fluxo de uso. Cálculos, filtros, agregações e visualizações DEVEM ser determinísticos, validados contra os dados de origem e livres de erros silenciosos ou estados inconsistentes na interface.

### III. Estética e Experiência do Usuário
O design DEVE ser agradável, coerente e intuitivo. A interface DEVE manter hierarquia visual clara, paleta de cores consistente, tipografia legível e navegação autoexplicativa, evitando sobrecarga cognitiva e elementos visuais desconexos.

### IV. Integração com o Relatório
Os resultados exibidos no aplicativo DEVEM refletir fielmente a análise apresentada no relatório do projeto. Métricas, definições, premissas, recortes temporais e conclusões apresentados na aplicação e no relatório DEVEM permanecer sincronizados a partir de uma mesma base analítica, sem divergências numéricas ou conceituais.

### V. Organização do Código e Boas Práticas
O código DEVE ser claro, modularmente estruturado e acompanhado de comentários adequados que expliquem decisões não óbvias e a intenção de blocos complexos. O desenvolvimento DEVE seguir boas práticas de R (e das demais linguagens utilizadas no projeto), priorizando legibilidade, separação de responsabilidades, reutilização de funções e ausência de código morto ou duplicado.

## Padrões Técnicos (R e Aplicação)

- **Boas Práticas em R**: Todo código R DEVE seguir guia de estilo consistente (ex.: tidyverse style guide), utilizando nomes descritivos em `snake_case`, funções pequenas e de responsabilidade única, vetorização em vez de laços imperativos desnecessários, referência explícita de pacotes/namespaces quando apropriado e caminhos relativos ao projeto (nunca caminhos absolutos locais).
- **Reprodutibilidade e Estrutura**: Scripts de processamento, análise, geração de relatório e aplicação DEVEM ser organizados em diretórios claros, com dependências documentadas e resultados reproduzíveis a partir dos dados versionados ou documentados.
- **Qualidade de Comentários**: Comentários DEVEM explicar o *porquê* de regras de negócio, transformações ou escolhas analíticas, evitando comentários redundantes sobre o que a sintaxe já expressa.

## Fluxo de Trabalho no GitHub e Git

- **Avaliação via GitHub**: A utilização do GitHub faz parte da avaliação do projeto; portanto, o histórico de desenvolvimento DEVE evidenciar criação e gestão disciplinada de branches, commits e Pull Requests (PRs).
- **Branches e Pull Requests**: Novas funcionalidades, correções e atualizações do relatório DEVEM ser desenvolvidas em branches dedicadas e integradas à branch principal exclusivamente via Pull Request, com descrição clara das alterações e verificação dos critérios desta constituição.
- **Commits e Staging Explícito (NÃO NEGOCIÁVEL)**: Commits DEVEM ser atômicos, frequentes e com mensagens descritivas. É ESTRITAMENTE PROIBIDO o uso de `git add .` ou `git add -A`; todos os arquivos DEVEM ser adicionados explicitamente ao stage (`git add <caminho-do-arquivo>`) para evitar a inclusão acidental de arquivos temporários, sensíveis ou fora de escopo.

## Governance

Esta Constituição prevalece sobre quaisquer outras práticas ad hoc do repositório. Todo Pull Request e revisão de código DEVE verificar explicitamente: (1) consistência funcional e alinhamento com o relatório, (2) aderência às boas práticas de R e organização do código, e (3) conformidade com o fluxo de branches, PRs e proibição de `git add .` / `git add -A`.

Emendas a esta Constituição exigem documentação da motivação, atualização da data `Last Amended` e incremento de versão segundo versionamento semântico:
- **MAJOR**: Remoção ou redefinição incompatível de princípios ou regras obrigatórias.
- **MINOR**: Adição de novo princípio/seção ou expansão material de diretrizes existentes.
- **PATCH**: Esclarecimentos, ajustes de redação ou correções não semânticas.

**Version**: 1.0.0 | **Ratified**: 2026-11-21 | **Last Amended**: 2026-11-21
