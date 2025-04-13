# GLB Physics Activator Plugin

Um plugin para o [Godot Engine](https://godotengine.org/) que ativa a geração de física para múltiplos arquivos GLB de uma vez. O plugin percorre uma pasta selecionada, modificando os arquivos de configuração `.import` dos arquivos GLB para que a física seja gerada automaticamente durante a importação.

## Funcionalidades

- **Ativação da Física em Lote**: Habilita a geração de física para vários arquivos GLB simultaneamente, modificando os respectivos arquivos `.import`.
- **Processamento em Lotes**: Processa os arquivos em pequenos grupos para evitar travamentos do editor e garantir uma execução suave.
- **Feedback Visual**: Exibe um diálogo com uma barra de progresso e mensagens, mantendo o usuário informado sobre o andamento do processamento.
- **Backup e Segurança**: Cria backups dos arquivos `.import` antes de realizar modificações, restaurando-os em caso de erros.
- **Integração com o Editor**: Adiciona um botão na barra de ferramentas do editor, facilitando o acesso e o uso do plugin diretamente do ambiente de desenvolvimento.

## Pré-requisitos

- **Godot Engine**: Versão 3.x ou superior com suporte a plugins de editor.
- **GDScript**: O plugin é escrito em GDScript e deve ser colocado na pasta correta do seu projeto.

## Instalação

1. **Clone ou copie os arquivos do plugin** para uma pasta dentro do seu projeto, por exemplo:  
   `res://addons/glb_physics_activator/`
2. **Ative o plugin**:
   - Abra o projeto no Godot.
   - Navegue até **Project > Project Settings > Plugins**.
   - Encontre o `GLB Physics Activator Plugin` na lista e altere seu estado para **Active**.

## Uso

1. **Acessar o Plugin**:  
   Após ativar o plugin, um botão intitulado **"Ativar Física GLB"** aparecerá na barra superior do editor.
2. **Selecionar Pasta**:  
   Clique no botão para abrir um diálogo de seleção de diretório. Escolha a pasta que contém os arquivos GLB que deseja processar.
3. **Processamento**:  
   - O plugin coleta todos os arquivos GLB na pasta selecionada.
   - Em lotes, ele modifica cada arquivo `.import` para incluir a geração de física.
   - A interface exibirá uma barra de progresso e mensagens que informam o andamento e o status de cada arquivo processado.
4. **Finalização**:  
   Ao concluir o processamento, uma notificação mostrará a quantidade de arquivos processados com sucesso e os que apresentaram erro. Recomenda-se reiniciar o editor para que todas as alterações sejam corretamente aplicadas.
   > **Importante**: Após a edição dos arquivos `.import`, é necessário fazer a reimportação dos arquivos GLB ou reiniciar o editor/projeto para que as alterações sejam efetivamente aplicadas.


## Estrutura do Código

- **Inicialização e Limpeza**:  
  As funções `_enter_tree()` e `_exit_tree()` cuidam da inicialização do plugin e da limpeza dos recursos quando o plugin é desativado.
- **Botão na Toolbar**:  
  Um botão é criado e adicionado à barra de ferramentas do editor, possibilitando o acionamento do plugin.
- **Diálogo de Seleção de Diretório e Progresso**:  
  Um `EditorFileDialog` permite selecionar a pasta com os arquivos GLB, enquanto um `AcceptDialog` exibe o progresso da operação.
- **Processamento dos Arquivos**:  
  - A função `_on_dir_selected()` coleta os arquivos GLB e inicia o processamento.
  - A função `_process_glb_files()` trata os arquivos em lotes, atualizando a barra de progresso.
  - A função `_enable_physics_for_glb()` realiza a verificação e a modificação necessária no arquivo `.import`, assegurando que a configuração de física seja incluída.
- **Backup e Segurança**:  
  Antes de modificar os arquivos, o plugin cria um backup do arquivo `.import` para garantir a possibilidade de restauração em caso de falhas.
- **Notificações e Diálogos de Erro**:  
  O plugin utiliza diálogos para informar o usuário sobre o sucesso ou a ocorrência de problemas durante o processamento.

## Observações

**Atenção:**  
- Este plugin é fornecido "no estado em que se encontra".  
- **Não me responsabilizo por qualquer perda de arquivos ou erros ocorridos na engine.**  
- O uso deste plugin é de responsabilidade do usuário, e deve ser testado em projetos de desenvolvimento ou backup antes de ser aplicado em ambientes de produção.

## Contribuindo

Contribuições são bem-vindas! Se você deseja sugerir melhorias, correções ou implementar novas funcionalidades, siga os passos abaixo:

1. Faça um fork deste repositório.
2. Crie uma branch para sua feature (por exemplo: `git checkout -b minha-feature`).
3. Realize as alterações desejadas e faça commit (`git commit -m 'Implementa nova feature'`).
4. Envie as alterações (`git push origin minha-feature`).
5. Abra um Pull Request explicando suas modificações.

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE). Sinta-se à vontade para utilizar e modificar o plugin conforme suas necessidades.

---

Se houver dúvidas ou sugestões, abra uma issue no repositório!
