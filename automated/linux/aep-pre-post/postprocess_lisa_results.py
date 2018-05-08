import argparse
import csv


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-f",
                        "--file",
                        help="CSV file for postprocessing",
                        dest="source_filename")
    parser.add_argument("-o",
                        "--output-file",
                        help="Results file",
                        dest="results_filename")
    args = parser.parse_args()

    row_index = 0
    headers = []
    measurements = {}
    with open(args.source_filename, "rb") as f:
        reader = csv.reader(f)
        for row in reader:
            if row_index == 0:
                headers = row
            elif row_index > 0 and row_index <=2:
                item_index = 0
                for item in row:
                    if len(item) > 0:
                        headers[item_index] = headers[item_index] + "_" + item
                    item_index = item_index + 1
            else:
                # concatenate first 3 cells
                name = row[0] + "_" + row[1] + "_" + row[2]
                item_index = 3
                for item in row[item_index:]:
                    if item != "":
                        measurement_name = name + "_" + headers[item_index]
                        measurements.update({measurement_name: item})
                    item_index = item_index + 1
            row_index = row_index + 1
    with open(args.results_filename, "a") as results:
        for key, value in measurements.items():
            # key is test name
            # value is measurement to be recorded
            results.write("%s pass %s _\r\n" % (key, value))

if __name__ == "__main__":
    main()
