def add_result(result_file, result):
    print(result)
    with open(result_file, 'a') as f:
        f.write('%s\n' % result)
