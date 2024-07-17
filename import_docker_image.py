import os

image_list = os.popen('ls ./docker_images/*.tar').read().split('\n')

print(image_list)

for i in image_list:
    cmd = ("docker image load -i %s" %i)
    os.system(cmd)
    print("imported: %s " %i)
