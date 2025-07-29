import nptdms
import argparse

def main(file_name):
    file = nptdms.TdmsFile.read_metadata(file_name)

    groups: list[nptdms.TdmsGroup] = file.groups()
    for g in groups:
        print(g.name)
        for c in g.channels():
            print(f"    {c.name}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument(
        'filename',
        nargs='?',
        default='test/medium.tdms',
    )

    args = parser.parse_args()

    main(args.filename)
