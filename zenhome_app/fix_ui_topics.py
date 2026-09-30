import sys

def replace_in_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    content = content.replace(
        'getDynamicDeviceTopicsList(activeConfig)', 
        'getSortedDeviceTopicsList(context, activeConfig)'
    )
    content = content.replace(
        'getDynamicDeviceTopicsList(ref.read(homeConfigProvider).activeConfig)', 
        'getSortedDeviceTopicsList(context, ref.read(homeConfigProvider).activeConfig)'
    )
    
    with open(filepath, 'w') as f:
        f.write(content)

replace_in_file('lib/features/home/ui/scene_section.dart')
replace_in_file('lib/features/home/ui/schedule_section.dart')
replace_in_file('lib/features/home/ui/timer_section.dart')

print("Done")
