@tool
extends EditorPlugin

var _toolbar_button: Button = null
var _file_dialog: EditorFileDialog = null
var _progress_dialog: AcceptDialog = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null
var _processing_files: bool = false
var _cancel_processing: bool = false

func _enter_tree() -> void:
	# Limpa recursos anteriores para evitar duplicações
	_exit_tree()
	
	# Cria e configura o botão na barra superior
	_toolbar_button = Button.new()
	_toolbar_button.text = "Ativar Física GLB"
	_toolbar_button.tooltip_text = "Seleciona uma pasta e ativa física para todos os arquivos GLB."
	_toolbar_button.pressed.connect(_on_button_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar_button)

	# Cria o diálogo de seleção de diretório
	_file_dialog = EditorFileDialog.new()
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.dir_selected.connect(_on_dir_selected)
	get_editor_interface().get_base_control().add_child(_file_dialog)
	
	# Criar diálogo de progresso
	_create_progress_dialog()
	
	print("Plugin GLB Physics Activator inicializado.")

func _exit_tree() -> void:
	if _toolbar_button:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar_button)
		_toolbar_button.queue_free()
		_toolbar_button = null
	
	if _file_dialog:
		if _file_dialog.get_parent():
			_file_dialog.get_parent().remove_child(_file_dialog)
		_file_dialog.queue_free()
		_file_dialog = null
		
	if _progress_dialog:
		if _progress_dialog.get_parent():
			_progress_dialog.get_parent().remove_child(_progress_dialog)
		_progress_dialog.queue_free()
		_progress_dialog = null
		_progress_bar = null
		_progress_label = null

func _create_progress_dialog() -> void:
	_progress_dialog = AcceptDialog.new()
	_progress_dialog.title = "Processando GLB"
	_progress_dialog.size = Vector2(400, 180)
	_progress_dialog.get_ok_button().text = "Fechar"
	_progress_dialog.close_requested.connect(_on_progress_dialog_close_requested)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_progress_label = Label.new()
	_progress_label.text = "Ativando física nos arquivos GLB..."
	vbox.add_child(_progress_label)
	
	_progress_bar = ProgressBar.new()
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	
	vbox.add_child(_progress_bar)
	
	# Adicionar botão de cancelar
	var cancel_button = Button.new()
	cancel_button.text = "Cancelar Processamento"
	cancel_button.pressed.connect(_on_cancel_pressed)
	vbox.add_child(cancel_button)
	
	_progress_dialog.add_child(vbox)
	
	get_editor_interface().get_base_control().add_child(_progress_dialog)

func _on_cancel_pressed() -> void:
	_cancel_processing = true
	_progress_label.text = "Cancelando processamento..."

func _on_progress_dialog_close_requested() -> void:
	if _processing_files:
		_cancel_processing = true
		_progress_label.text = "Cancelando processamento..."
	else:
		_progress_dialog.hide()

func _on_button_pressed() -> void:
	if _file_dialog and not _processing_files:
		_file_dialog.popup_centered_ratio(0.7)

func _safely_close_file(file: FileAccess) -> void:
	if file != null:
		file.close()

func _on_dir_selected(dir_path: String) -> void:
	if _processing_files:
		return
		
	_processing_files = true
	_cancel_processing = false
	
	var dir = DirAccess.open(dir_path)
	if not dir:
		_show_error_dialog("Não foi possível abrir o diretório: " + dir_path)
		_processing_files = false
		return
	
	var glb_files = []
	
	# Primeiro, colete todos os arquivos GLB
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.get_extension().to_lower() == "glb":
			var file_path = dir_path.path_join(file_name)
			glb_files.append(file_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if glb_files.is_empty():
		_show_notification_dialog("Nenhum arquivo GLB encontrado no diretório selecionado.")
		_processing_files = false
		return
	
	# Mostra o diálogo de progresso
	_progress_dialog.popup_centered()
	_progress_bar.max_value = glb_files.size()
	_progress_bar.value = 0
	
	# Processa os arquivos um por um com um CallDeferred para evitar sobrecarga da thread principal
	call_deferred("_start_processing_glb_files", glb_files)

func _start_processing_glb_files(glb_files: Array) -> void:
	# Usar um timer para iniciar o processamento no próximo quadro
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.1
	add_child(timer)
	timer.timeout.connect(func(): 
		remove_child(timer)
		timer.queue_free()
		_process_glb_files(glb_files)
	)
	timer.start()

func _process_glb_files(glb_files: Array) -> void:
	var success_count = 0
	var error_count = 0
	var processed_count = 0
	var canceled_count = 0
	
	# Definir um tamanho de lote menor
	var batch_size = 1  # Processar apenas 1 arquivo por vez para reduzir a carga
	
	# Calcular número total de lotes
	var total_batches = ceil(float(glb_files.size()) / batch_size)
	
	for batch in range(total_batches):
		if _cancel_processing:
			canceled_count = glb_files.size() - processed_count
			break
			
		var start_idx = batch * batch_size
		var end_idx = min(start_idx + batch_size, glb_files.size())
		
		# Processar este lote de arquivos
		for i in range(start_idx, end_idx):
			if _cancel_processing:
				canceled_count = glb_files.size() - processed_count
				break
				
			var file_path = glb_files[i]
			processed_count += 1
			
			_progress_label.text = "Processando: " + file_path.get_file() + " (" + str(processed_count) + "/" + str(glb_files.size()) + ")"
			print("Processando: " + file_path)
			
			# Atualiza a barra de progresso
			_progress_bar.value = processed_count
			
			# Força atualização da interface e permitir que eventos sejam processados
			for _i in range(5):  # Múltiplos frames para garantir
				await get_tree().process_frame
			
			# Tenta ativar física para o arquivo GLB
			var result = await _enable_physics_for_glb(file_path)
			if result:
				success_count += 1
			else:
				error_count += 1
		
		# Aguardar entre lotes para permitir que o editor respire
		if not _cancel_processing:
			_progress_label.text = "Aguardando para processar próximo lote... (" + str(processed_count) + "/" + str(glb_files.size()) + ")"
			for _i in range(10):  # Dar mais tempo para o editor respirar
				await get_tree().process_frame
			await get_tree().create_timer(0.5).timeout
	
	# Aguardar um tempo adicional para garantir que todas as operações do sistema de arquivos sejam concluídas
	_progress_label.text = "Finalizando e estabilizando o sistema de arquivos..."
	await get_tree().create_timer(1.0).timeout
	
	# Executa limpeza segura
	await _cleanup_after_processing()
	
	# Mostra o resultado
	var message = "Processamento concluído!\n"
	message += "Arquivos GLB encontrados: " + str(glb_files.size()) + "\n"
	message += "Arquivos processados com sucesso: " + str(success_count) + "\n"
	message += "Arquivos com erro: " + str(error_count) + "\n"
	
	if canceled_count > 0:
		message += "Processamento cancelado: " + str(canceled_count) + " arquivos não processados\n\n"
	else:
		message += "\n"
	
	message += "Os arquivos foram modificados. Recomendamos reiniciar o editor para garantir que as alterações sejam aplicadas corretamente."
	
	_show_notification_dialog(message)
	
	# Esconder o diálogo de progresso e resetar estado
	_progress_dialog.hide()
	_processing_files = false
	_cancel_processing = false

func _enable_physics_for_glb(file_path: String) -> bool:
	# Verifica se o arquivo existe
	if not FileAccess.file_exists(file_path):
		push_error("Arquivo não encontrado: " + file_path)
		return false
	
	# Verifica se o arquivo .import existe
	var import_file_path = file_path + ".import"
	if not FileAccess.file_exists(import_file_path):
		push_error("Arquivo .import não encontrado: " + import_file_path)
		return false
	
	# Criar backup do arquivo antes de modificá-lo
	var backup_path = import_file_path + ".bak"
	var backup_file = FileAccess.open(backup_path, FileAccess.WRITE)
	if backup_file == null:
		push_error("Não foi possível criar backup para: " + import_file_path)
		return false
	
	# Lê o conteúdo do arquivo .import
	var import_file = FileAccess.open(import_file_path, FileAccess.READ)
	if import_file == null:
		push_error("Não foi possível abrir o arquivo: " + import_file_path)
		_safely_close_file(backup_file)
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		return false
	
	var import_config_text = import_file.get_as_text()
	_safely_close_file(import_file)
	
	# Salvar backup
	backup_file.store_string(import_config_text)
	_safely_close_file(backup_file)
	
	# Extrai o nome do arquivo sem a extensão para usar como referência do nó
	var file_name = file_path.get_file().get_basename()
	
	# Verifica se já existe física ativada
	if import_config_text.find("\"generate/physics\": true") != -1:
		print("Física já ativada para: " + file_path)
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)  # Remove backup se não for necessário
		return true
	
	# Modificações específicas para ativar a física no formato correto
	var modified = false
	
	# Procura a seção _subresources
	var subresources_pos = import_config_text.find("_subresources=")
	
	if subresources_pos != -1:
		# Verificar o formato atual de _subresources
		var existing_subresources_start = import_config_text.find("{", subresources_pos)
		var existing_subresources_end = _find_matching_brace(import_config_text, existing_subresources_start)
		
		if existing_subresources_start != -1 and existing_subresources_end != -1:
			var existing_subresources = import_config_text.substr(
				existing_subresources_start, 
				existing_subresources_end - existing_subresources_start + 1
			)
			
			if existing_subresources == "{}":
				# Subresources vazio, substituir completamente
				var new_subresources = "{\n\"nodes\": {\n\"PATH:tmpParent/" + file_name + "\": {\n\"generate/physics\": true\n}\n}\n}"
				import_config_text = import_config_text.replace("{}", new_subresources)
			else:
				# Já tem conteúdo, verificar se já tem a seção "nodes"
				var nodes_pos = import_config_text.find("\"nodes\":", subresources_pos)
				
				# Verificar se nodes_pos está dentro dos limites de _subresources
				if nodes_pos != -1 and nodes_pos < existing_subresources_end:
					# Já tem nodes, adicionar nosso nó
					var nodes_brace_start = import_config_text.find("{", nodes_pos)
					var nodes_brace_end = _find_matching_brace(import_config_text, nodes_brace_start)
					
					if nodes_brace_start != -1 and nodes_brace_end != -1:
						# Verificar se este nó específico já existe
						var node_path = "\"PATH:tmpParent/" + file_name + "\""
						var node_pos = import_config_text.find(node_path, nodes_pos)
						
						# Verificar se node_pos está dentro dos limites de nodes
						if node_pos == -1 or node_pos > nodes_brace_end:
							# Adicionar nosso nó antes do fechamento do "nodes"
							var node_entry = "\n\"PATH:tmpParent/" + file_name + "\": {\n\"generate/physics\": true\n}"
							# Se o último caractere antes do fechamento não for vírgula, adicionar uma
							var insert_pos = nodes_brace_end
							var char_before = import_config_text.substr(insert_pos - 1, 1)
							if char_before != "{" and char_before != ",":
								node_entry = "," + node_entry
							import_config_text = import_config_text.insert(insert_pos, node_entry)
						else:
							# O nó já existe, verificar se já tem generate/physics
							var node_brace_start = import_config_text.find("{", node_pos)
							var node_brace_end = _find_matching_brace(import_config_text, node_brace_start)
							
							if node_brace_start != -1 and node_brace_end != -1:
								var physics_pos = import_config_text.find("\"generate/physics\":", node_pos)
								if physics_pos == -1 or physics_pos > node_brace_end:
									# Adicionar generate/physics neste nó
									var physics_entry = "\n\"generate/physics\": true"
									# Se o último caractere antes do fechamento não for vírgula, adicionar uma
									var insert_pos = node_brace_end
									var char_before = import_config_text.substr(insert_pos - 1, 1)
									if char_before != "{" and char_before != ",":
										physics_entry = "," + physics_entry
									import_config_text = import_config_text.insert(insert_pos, physics_entry)
				else:
					# Não tem nodes, adicionar seção nodes com nosso nó
					var insert_pos = existing_subresources_end
					var nodes_section = "\n\"nodes\": {\n\"PATH:tmpParent/" + file_name + "\": {\n\"generate/physics\": true\n}\n}"
					# Se o último caractere antes do fechamento não for vírgula, adicionar uma
					var char_before = import_config_text.substr(insert_pos - 1, 1)
					if char_before != "{" and char_before != ",":
						nodes_section = "," + nodes_section
					import_config_text = import_config_text.insert(insert_pos, nodes_section)
			
			modified = true
	else:
		# Não tem _subresources, adicionar completamente
		var subresources_line = "_subresources={\n\"nodes\": {\n\"PATH:tmpParent/" + file_name + "\": {\n\"generate/physics\": true\n}\n}\n}"
		
		# Encontrar onde inserir _subresources (antes de gltf/naming_version)
		var gltf_pos = import_config_text.find("gltf/naming_version")
		if gltf_pos != -1:
			import_config_text = import_config_text.insert(gltf_pos, subresources_line + "\n")
		else:
			# Se não encontrar gltf/naming_version, adicionar no final da seção [params]
			var params_pos = import_config_text.find("[params]")
			if params_pos != -1:
				var next_section = import_config_text.find("[", params_pos + 8)
				if next_section != -1:
					import_config_text = import_config_text.insert(next_section, subresources_line + "\n")
				else:
					import_config_text += subresources_line + "\n"
		
		modified = true
	
	if modified:
		# Permitir frames de respiração antes da escrita
		for _i in range(3):
			await get_tree().process_frame
		
		# Escreve as alterações de volta no arquivo .import usando sistema de tentativas
		var max_attempts = 3
		var attempt = 0
		var success = false
		
		while attempt < max_attempts and not success:
			# Esperar um pouco antes de tentar
			if attempt > 0:
				await get_tree().create_timer(0.5).timeout
			
			var output_file = FileAccess.open(import_file_path, FileAccess.WRITE)
			if not output_file:
				push_error("Tentativa " + str(attempt + 1) + ": Não foi possível escrever no arquivo: " + import_file_path)
				attempt += 1
				continue
			
			output_file.store_string(import_config_text)
			_safely_close_file(output_file)
			
			# Verificar se a escrita funcionou
			if FileAccess.file_exists(import_file_path):
				success = true
			else:
				attempt += 1
		
		if not success:
			# Restaurar backup se todas as tentativas falharem
			var backup_restore = FileAccess.open(backup_path, FileAccess.READ)
			if backup_restore:
				var original_content = backup_restore.get_as_text()
				_safely_close_file(backup_restore)
				
				var restore_file = FileAccess.open(import_file_path, FileAccess.WRITE)
				if restore_file:
					restore_file.store_string(original_content)
					_safely_close_file(restore_file)
			
			push_error("Não foi possível modificar o arquivo após várias tentativas: " + import_file_path)
			return false
		
		# Aguarda um pouco antes de notificar o filesystem
		await get_tree().create_timer(0.3).timeout
		
		# Frames de respiração antes de continuar
		for _i in range(5):
			await get_tree().process_frame
		
		# Remover o backup se tudo correu bem
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		
		print("Física ativada para: " + file_path)
		return true
	
	# Remover o backup se não houve alterações
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	return false

# Função de limpeza segura após o processamento
func _cleanup_after_processing() -> void:
	# Garantir que todos os diálogos sejam fechados corretamente
	if _progress_dialog and _progress_dialog.visible:
		_progress_dialog.hide()
	
	# Dar tempo para o editor respirar
	for _i in range(10):
		await get_tree().process_frame
	
	# Notificar o filesystem uma última vez de forma suave
	var editor_filesystem = get_editor_interface().get_resource_filesystem()
	editor_filesystem.scan()
	
	# Mais tempo para processamento
	await get_tree().create_timer(0.5).timeout
	
	print("Limpeza após processamento concluída.")

# Função auxiliar para encontrar a chave correspondente em uma string JSON
func _find_matching_brace(text: String, open_pos: int) -> int:
	var depth = 1
	var pos = open_pos + 1
	
	while pos < text.length() and depth > 0:
		var c = text[pos]
		if c == '{':
			depth += 1
		elif c == '}':
			depth -= 1
		pos += 1
	
	if depth == 0:
		return pos - 1
	else:
		return -1

# Cria e mostra um diálogo de notificação
func _show_notification_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "GLB Physics Activator"
	dialog.size = Vector2(400, 250)
	dialog.confirmed.connect(func(): dialog.queue_free())
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()

# Cria e mostra um diálogo de erro
func _show_error_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Erro"
	dialog.size = Vector2(400, 150)
	dialog.confirmed.connect(func(): dialog.queue_free())
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()