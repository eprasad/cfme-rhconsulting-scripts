class DialogImportExport
  class ParsedNonDialogYamlError < StandardError; end

  def export(filedir)
    raise "Must supply filedir" if filedir.blank?
    dialogs_hash = export_dialogs(Dialog.order(:id).all)
    dialogs_hash.each { |x|
      data = []
      data << x
      File.write("#{filedir}/#{x['label']}.yml", data.to_yaml)
    }
  end

  def import(filedir)
    raise "Must supply filedir" if filedir.blank?
    Dialog.transaction do
      Dir.foreach(filedir) do |filename|
        next if filename == '.' or filename == '..'
        import_dialogs_from_file("#{filedir}/#{filename}")
      end
    end
  end

  private

  def import_dialogs_from_file(filename)
    dialogs = YAML.load_file(filename)
    import_dialogs(dialogs)
  end

  def import_dialogs(dialogs)
    begin
      dialogs.each do |d|
        puts "Dialog: [#{d['label']}]"
        dialog = Dialog.find_by_label(d["label"])
        if dialog
          dialog.update_attributes!("dialog_tabs" => import_dialog_tabs(d))
        else
          Dialog.create(d.merge("dialog_tabs" => import_dialog_tabs(d)))
        end
      end
    rescue
      raise ParsedNonDialogYamlError
    end
  end

  def import_dialog_tabs(dialog)
    dialog["dialog_tabs"].collect do |dialog_tab|
      DialogTab.create(dialog_tab.merge("dialog_groups" => import_dialog_groups(dialog_tab)))
    end
  end

  def import_dialog_groups(dialog_tab)
    dialog_tab["dialog_groups"].collect do |dialog_group|
      DialogGroup.create(dialog_group.merge("dialog_fields" => import_dialog_fields(dialog_group)))
    end
  end

  def import_dialog_fields(dialog_group)
    dialog_group["dialog_fields"].collect do |dialog_field|
      df = dialog_field['type'].constantize.create(dialog_field.reject { |a| ['resource_action_fqname'].include?(a) })
      unless dialog_field['resource_action_fqname'].blank?
        df.resource_action.fqname = dialog_field['resource_action_fqname']
        df.resource_action.save!
      end
      df
    end
  end

  def export_dialogs(dialogs)
    dialogs.map do |dialog|
      dialog_tabs = export_dialog_tabs(dialog.dialog_tabs)

      included_attributes(dialog.attributes, ["created_at", "id", "updated_at"]).merge("dialog_tabs" => dialog_tabs)
    end
  end

  def export_resource_action(resource_action)
    included_attributes(resource_action.attributes, ["created_at", "resource_id", "id", "updated_at"])
  end

  def export_dialog_fields(dialog_fields)
    dialog_fields.map do |dialog_field|
      field_attributes = included_attributes(dialog_field.attributes, ["created_at", "dialog_group_id", "id", "updated_at"])
      if dialog_field.respond_to?(:resource_action) && dialog_field.resource_action
        field_attributes["resource_action_fqname"] = dialog_field.resource_action.fqname
      end
      field_attributes
    end
  end

  def export_dialog_groups(dialog_groups)
    dialog_groups.map do |dialog_group|
      dialog_fields = export_dialog_fields(dialog_group.dialog_fields)

      included_attributes(dialog_group.attributes, ["created_at", "dialog_tab_id", "id", "updated_at"]).merge("dialog_fields" => dialog_fields)
    end
  end

  def export_dialog_tabs(dialog_tabs)
    dialog_tabs.map do |dialog_tab|
      dialog_groups = export_dialog_groups(dialog_tab.dialog_groups)

      included_attributes(dialog_tab.attributes, ["created_at", "dialog_id", "id", "updated_at"]).merge("dialog_groups" => dialog_groups)
    end
  end

  def included_attributes(attributes, excluded_attributes)
    attributes.reject { |key, _| excluded_attributes.include?(key) }
  end

end

namespace :rhconsulting do
  namespace :dialogs do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake rhconsulting:dialogs:export[/path/to/dir/with/dialogs]'
      puts 'Import - Usage: rake rhconsulting:dialogs:import[/path/to/dir/with/dialogs]'
    end

    desc 'Import all dialogs to individual YAML files'
    task :import, [:filedir] => [:environment] do |_, arguments|
      DialogImportExport.new.import(arguments[:filedir])
    end

    desc 'Exports all dialogs to individual YAML files'
    task :export, [:filedir] => [:environment] do |_, arguments|
      DialogImportExport.new.export(arguments[:filedir])
    end

  end
end


