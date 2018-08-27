# coding: utf-8
import os
current_path = os.path.abspath(os.path.dirname(__file__))


def replaced_file_string(template, key_file_dict):
    with open(template) as f:
        fs = f.read()
        for k, txt_file in key_file_dict.items():
            with open(txt_file) as tf:
                fs = fs.replace(k, tf.read())
        return fs


def replace_files(*templates):
    for template in templates:
        s = replaced_file_string(
            template,
            {
                "{{ZJHL_CA_CERT}}": os.path.join(current_path, "fabric-config", "ca-zjhl.txt"),
                "{{ORDERERS_CA_CERT}}": os.path.join(current_path, "fabric-config", "ca-orderers.txt"),
            }
        )
        with open(template, "w") as jf:
            jf.write(s)


zjhl = os.path.join(current_path, "zjhl.json")
replace_files(zjhl)