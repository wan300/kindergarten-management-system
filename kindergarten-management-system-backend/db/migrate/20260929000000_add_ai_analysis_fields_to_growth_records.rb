class AddAiAnalysisFieldsToGrowthRecords < ActiveRecord::Migration[7.0]
  def change
    add_column :growth_records, :analysis_status, :string, null: false, default: "pending"
    add_column :growth_records, :analysis_model, :string
    add_column :growth_records, :analysis_generated_at, :datetime
    add_column :growth_records, :analysis_error, :text
    add_index :growth_records, :analysis_status

    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE growth_records
          SET analysis_status = 'legacy'
          WHERE analysis IS NOT NULL AND TRIM(analysis) <> ''
        SQL
      end
    end
  end
end
