import os
import pandas as pd
from io import StringIO

def clean_and_convert_specific_dat_files():
    """
    Cleans and converts only the specified .dat files in the input directory to .csv files
    with explicit output names: 'household.csv', 'person.csv', 'employment.csv'.
    All final CSV files are saved in the current directory.
    """
    # Define the input directory for .dat files
    input_directory = os.path.abspath(
        os.path.join(os.path.dirname(__file__), '..', '..', 'DaySim', 'inputs')
    )
    
    # Define the output directory as the current directory
    output_directory = os.path.dirname(os.path.abspath(__file__))
    
    # Map .dat files to their desired .csv output names
    files_to_process = {
        "household_2023.dat": "household.csv",
        "person_2023.dat": "person.csv",
        "nashville_mzbuffer_allstreets_2023.dat": "employment.csv",
    }

    try:
        files = [f for f in os.listdir(input_directory) if f in files_to_process]
    except FileNotFoundError:
        print(f"Error: Input directory not found: {input_directory}")
        return

    for dat_file in files:
        dat_path = os.path.join(input_directory, dat_file)
        csv_name = files_to_process[dat_file]
        csv_path = os.path.join(output_directory, csv_name)

        try:
            print(f"Processing {dat_file}...")

            with open(dat_path, 'r') as file:
                clean_lines = [' '.join(line.split()) for line in file]

            cleaned_data = StringIO('\n'.join(clean_lines))
            df = pd.read_csv(
                cleaned_data,
                delimiter=' ',
                engine='python',
                header=None
            )

            df.to_csv(csv_path, index=False, header=False)
            print(f"Converted {dat_file} to {csv_name}")

        except Exception as e:
            print(f"Failed to process {dat_file}: {e}")

def add_pptaz_to_person_file():
    """
    Adds a 'pptaz' column to the person file by joining it with the household file using 'hhno'.
    """
    # Use the current directory
    working_directory = os.path.dirname(os.path.abspath(__file__))
    hh_file = os.path.join(working_directory, "household.csv")
    pp_file = os.path.join(working_directory, "person.csv")

    if not os.path.exists(hh_file):
        print(f"Household file not found: {hh_file}")
        return
    if not os.path.exists(pp_file):
        print(f"Person file not found: {pp_file}")
        return

    try:
        hh_df = pd.read_csv(hh_file)
        pp_df = pd.read_csv(pp_file)

        if 'hhno' not in hh_df.columns or 'hhtaz' not in hh_df.columns:
            print("Household file must contain 'hhno' and 'hhtaz' columns.")
            return
        if 'hhno' not in pp_df.columns:
            print("Person file must contain 'hhno' column.")
            return

        pp_df['pptaz'] = pp_df['hhno'].map(hh_df.set_index('hhno')['hhtaz'])

        updated_pp_file = os.path.join(working_directory, "person_updated.csv")
        pp_df.to_csv(updated_pp_file, index=False)
        print(f"Updated person file saved to: {updated_pp_file}")

    except Exception as e:
        print(f"An error occurred: {e}")

def create_summary_csv():
    """
    Creates a summary CSV file with columns TAZID, households, population, and employment.
    Ensures all TAZIDs from 1 to 3008 are included.
    """
    # Use the current directory for inputs and output
    working_directory = os.path.dirname(os.path.abspath(__file__))
    hh_file = os.path.join(working_directory, "household.csv")
    updated_pp_file = os.path.join(working_directory, "person_updated.csv")
    mzbuffer_file = os.path.join(working_directory, "employment.csv")

    if not (os.path.exists(hh_file) and os.path.exists(updated_pp_file) and os.path.exists(mzbuffer_file)):
        print("One or more required files are missing.")
        return

    try:
        hh_df = pd.read_csv(hh_file)
        pp_df = pd.read_csv(updated_pp_file)
        mzbuffer_df = pd.read_csv(mzbuffer_file)

        hh_summary = hh_df.groupby('hhtaz').size().reset_index(name='households')
        pop_summary = pp_df.groupby('pptaz').size().reset_index(name='population')
        emp_summary = mzbuffer_df.groupby('taz_p')['emptot_p'].sum().reset_index(name='employment')

        summary = hh_summary.merge(pop_summary, left_on='hhtaz', right_on='pptaz', how='outer') \
                             .merge(emp_summary, left_on='hhtaz', right_on='taz_p', how='outer')

        summary = summary.rename(columns={'hhtaz': 'TAZID'}).fillna(0)

        all_taz_ids = pd.DataFrame({'TAZID': range(1, 3009)})
        summary = all_taz_ids.merge(summary, on='TAZID', how='left').fillna(0)

        summary = summary[['TAZID', 'households', 'population', 'employment']]
        summary['TAZID'] = summary['TAZID'].astype(int)

        summary_file = os.path.join(working_directory, "taz_summary.csv")
        summary.to_csv(summary_file, index=False)
        print(f"Summary file saved to: {summary_file}")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    clean_and_convert_specific_dat_files()
    add_pptaz_to_person_file()
    create_summary_csv()
