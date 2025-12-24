class ArticlesImportJob < ApplicationJob
  queue_as :default

  def perform(store_id, csv1_path, csv2_path)
    store = Store.find(store_id)

    Articles::CsvImporter.import(
      csv1_path,
      csv2_path,
      store: store
    )
  ensure
    cleanup(csv1_path)
    cleanup(csv2_path)
  end

  private

  def cleanup(path)
    File.delete(path) if path && File.exist?(path)
  end
end