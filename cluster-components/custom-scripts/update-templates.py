import yaml
import os
import sys

DIR = os.environ.get('DIR')

templates_dir = os.path.join(DIR,'chart/cluster-components-operator/templates')
# print(os.path.realpath(templates_dir))
# sys.exit(0)
def change_image(input):
    if(input['name'] == 'manager'):
        input['image'] = "lucidprogrammer/cluster-components-operator:{{.Values.imageTag}}"
    return input

    
templates = [os.path.join(templates_dir,f) for f in os.listdir(templates_dir) if f.endswith('yaml')]
for template in templates:
    updated = ''
    with open(template,mode='r',encoding='utf-8') as reader:
        givens = yaml.load_all(reader.read(),Loader=yaml.FullLoader)
        for given in givens:
            if(given):
                labels = {
                    "app": "cluster-components-operator",
                    "heritage": "Helm",
                    "release" : "{{ .Release.Name }}",
                    "chart": "{{ include \"cluster-components-operator.chart\" . }}"
                }
                given['metadata']['labels']=labels
                if(given['kind'] == 'Deployment'):
                    containers = given['spec']['template']['spec']['containers']
                    given['spec']['template']['spec']['containers']=list(map(lambda a: change_image(a),containers))
                updated = '%s\n%s\n---' %(updated,yaml.dump(given))

    with open(template,mode='w',encoding='utf-8') as writer:
        writer.write(updated)

print('Templates updated!!')