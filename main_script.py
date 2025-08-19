import os
import json
import csv
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime


class CMSHospitalDataPipeline:

    def __init__(self):
        self.config = self.step1_load_constants()
        self.step2_create_directories()

    def step1_load_constants(self):
        return {
            'API_URL': 'https://data.cms.gov/provider-data/api/1/metastore/schemas/dataset/items',
            'METADATA_FILE': 'metadata.json',
            'DOWNLOAD_DIR': 'downloads',
            'CLEANED_DIR': 'cleaned',
            'MAX_WORKERS': 5,
            'THEME_FILTER': 'hospitals',
            'CSV_EXTENSION': '.csv',
            'CLEANED_SUFFIX': '_cleaned',
            'DEFAULT_ENCODING': 'utf-8'
        }

    def step2_create_directories(self):
        os.makedirs(self.config['DOWNLOAD_DIR'], exist_ok=True)
        os.makedirs(self.config['CLEANED_DIR'], exist_ok=True)

    def step3_load_previous_metadata(self):
        metadata_file = self.config['METADATA_FILE']
        if os.path.exists(metadata_file):
            with open(metadata_file, "r") as file:
                return json.load(file)
        return {"files": {}}

    def step4_save_metadata(self, metadata):
        metadata["last_run"] = datetime.now().isoformat()
        with open(self.config['METADATA_FILE'], "w") as file:
            json.dump(metadata, file, indent=2)

    def step5_fetch_all_datasets(self):
        with urllib.request.urlopen(self.config['API_URL']) as response:
            data = response.read()
            return json.loads(data.decode('utf-8'))

    def step6_filter_hospital_datasets(self, all_datasets):
        hospital_datasets = []
        theme_filter = self.config['THEME_FILTER'].lower()

        for dataset in all_datasets:
            title = dataset.get('title', '').lower()
            description = dataset.get('description', '').lower()
            theme = dataset.get('theme', [])
            keywords = dataset.get('keyword', [])

            is_hospital_related = (
                    theme_filter in title or
                    theme_filter in description or
                    any(theme_filter in str(t).lower() for t in theme) or
                    any(theme_filter in str(k).lower() for k in keywords) or
                    'hospital' in title or
                    'hospital' in description
            )

            if is_hospital_related:
                hospital_datasets.append(dataset)

        print(f"Found {len(hospital_datasets)} hospital-related datasets out of {len(all_datasets)} total datasets")
        return hospital_datasets

    def step7_find_new_or_updated_files(self, datasets, metadata):
        files_to_download = []

        for dataset in datasets:
            file_id = dataset['identifier']
            last_modified = dataset.get('modified')

            if file_id not in metadata["files"] or metadata["files"][file_id] != last_modified:
                files_to_download.append(dataset)

        return files_to_download

    def step8_download_single_file(self, dataset):
        if not dataset.get("distribution") or not dataset["distribution"]:
            raise ValueError(f"No distribution found for {dataset['identifier']}")

        download_url = dataset["distribution"][0]["downloadURL"]
        file_id = dataset['identifier']

        local_filename = os.path.join(self.config['DOWNLOAD_DIR'], f"{file_id}.csv")

        urllib.request.urlretrieve(download_url, local_filename)

        return local_filename, file_id

    def step9_download_files_parallel(self, datasets_to_download):
        with ThreadPoolExecutor(max_workers=self.config['MAX_WORKERS']) as executor:
            results = list(executor.map(self.step8_download_single_file, datasets_to_download))
        return results

    def step10_clean_column_name(self, column_name):
        clean_name = column_name.lower()
        clean_name = clean_name.replace("'", "")
        clean_name = clean_name.replace('"', "")
        clean_name = clean_name.replace("`", "")
        clean_name = clean_name.replace("(", "_")
        clean_name = clean_name.replace(")", "_")
        clean_name = clean_name.replace("%", "_")
        clean_name = clean_name.replace("&", "_")
        clean_name = clean_name.replace("-", "_")
        clean_name = clean_name.replace(" ", "_")

        while "__" in clean_name:
            clean_name = clean_name.replace("__", "_")

        if clean_name.startswith("_"):
            clean_name = clean_name[1:]
        if clean_name.endswith("_"):
            clean_name = clean_name[:-1]

        return clean_name

    def step11_process_single_file(self, file_path, file_id):
        rows = []
        original_headers = []

        with open(file_path, 'r', encoding='utf-8', newline='') as input_file:
            csv_reader = csv.reader(input_file)
            original_headers = next(csv_reader)

            for row in csv_reader:
                rows.append(row)

        cleaned_headers = []
        for header in original_headers:
            cleaned_headers.append(self.step10_clean_column_name(header))

        cleaned_filename = f"{file_id}_cleaned.csv"
        cleaned_path = os.path.join(self.config['CLEANED_DIR'], cleaned_filename)

        with open(cleaned_path, 'w', encoding='utf-8', newline='') as output_file:
            csv_writer = csv.writer(output_file)
            csv_writer.writerow(cleaned_headers)
            csv_writer.writerows(rows)

        return cleaned_path

    def step11_process_files_parallel(self, download_results):
        def process_single(file_info):
            file_path, file_id = file_info
            return self.step11_process_single_file(file_path, file_id)

        with ThreadPoolExecutor(max_workers=self.config['MAX_WORKERS']) as executor:
            results = list(executor.map(process_single, download_results))
        return results

    def step12_update_metadata(self, metadata, processed_datasets):
        for dataset in processed_datasets:
            file_id = dataset['identifier']
            last_modified = dataset.get('modified')
            metadata["files"][file_id] = last_modified
        return metadata

    def run_complete_pipeline(self):
        print("CMS Hospital Data Pipeline")
        print(f"Pipeline designed for daily execution at: {datetime.now().isoformat()}")

        metadata = self.step3_load_previous_metadata()

        all_datasets = self.step5_fetch_all_datasets()
        print(f"Fetched {len(all_datasets)} total datasets from CMS API")

        hospital_datasets = self.step6_filter_hospital_datasets(all_datasets)
        new_files = self.step7_find_new_or_updated_files(hospital_datasets, metadata)

        if not new_files:
            print("No new or updated files found since last run.")
            print("Pipeline completed - no downloads needed.")
            return

        print(f"Found {len(new_files)} files to download and process:")
        for dataset in new_files[:5]:  # Show first 5
            print(f"  - {dataset.get('title', 'Unknown')}")
        if len(new_files) > 5:
            print(f"  and {len(new_files) - 5} more")

        download_results = self.step9_download_files_parallel(new_files)
        print(f"Successfully downloaded {len(download_results)} files to '{self.config['DOWNLOAD_DIR']}' directory")

        processed_results = self.step11_process_files_parallel(download_results)
        print(f"Successfully processed {len(processed_results)} files with snake_case column names")
        print(f"Cleaned files saved to '{self.config['CLEANED_DIR']}' directory")

        if processed_results:
            self.show_sample_output(download_results[0])

        updated_metadata = self.step12_update_metadata(metadata, new_files)
        self.step4_save_metadata(updated_metadata)

        print("Pipeline Completed Successfully")
        print(f"Next run will only download files modified after: {datetime.now().isoformat()}")
        print("Schedule this script to run daily for incremental updates.")

    def show_sample_output(self, file_info):
        file_path, file_id = file_info

        try:
            with open(file_path, 'r', encoding='utf-8', newline='') as file:
                csv_reader = csv.reader(file)
                original_headers = next(csv_reader)

            print(f"\n=== Sample Column Name Transformations (from {file_id}) ===")
            for i, original in enumerate(original_headers[:3]):  # Show first 3 columns
                cleaned = self.step10_clean_column_name(original)
                print(f"  '{original}' → '{cleaned}'")
            if len(original_headers) > 3:
                print(f"  ... and {len(original_headers) - 3} more columns")
            print()

        except Exception as e:
            print(f"Could not show output: {e}")


def main():
    pipeline = CMSHospitalDataPipeline()
    pipeline.run_complete_pipeline()


if __name__ == "__main__":
    main()