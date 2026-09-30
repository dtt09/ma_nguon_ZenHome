import os
import shutil
import re

# Define the base directories
BASE_DIR = '/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app/lib'
FEATURES_DIR = os.path.join(BASE_DIR, 'features')

# Define the mapping of features to their UI and Logic files
# This is a basic mapping based on the previous tree output
file_mapping = {
    'auth': [
        'screens/auth/account_info_screen.dart',
        'screens/auth/change_password_screen.dart',
        'screens/auth/forgot_password_screen.dart',
        'screens/auth/google_confirm_screen.dart',
        'screens/auth/logged_devices_screen.dart',
        'screens/auth/login_screen.dart',
        'screens/auth/otp_verification_screen.dart',
        'screens/auth/phone_registration_screen.dart',
        'screens/auth/profile_screen.dart',
        'screens/auth/register_screen.dart',
        'screens/auth/reset_password_screen.dart',
        'screens/auth/update_email_phone_screen.dart',
        'screens/auth/mixins/login_logic_mixin.dart',
        'providers/auth_provider.dart',
        'providers/auth_provider.g.dart',
        'repositories/auth_repository.dart'
    ],
    'admin': [
        'screens/admin/admin_login_screen.dart',
        'screens/admin/device_mapping_screen.dart'
    ],
    'home': [
        'screens/dashboard_screen.dart',
        'screens/scenes_screen.dart',
        'screens/main_layout.dart',
        'screens/main_layout/components/disabled_view.dart',
        'screens/main_layout/mixins/auth_sync_mixin.dart',
        'screens/main_layout/mixins/home_sync_mixin.dart',
        'widgets/device_card.dart',
        'widgets/room_tab.dart',
        'widgets/scene_section.dart',
        'widgets/schedule_section.dart',
        'widgets/timer_section.dart',
        'widgets/weather_card.dart',
        'widgets/home_switcher_sheet.dart',
        'providers/home_config_provider.dart'
    ],
    'settings': [
        'screens/settings_screen.dart',
        'screens/settings/member_screen.dart',
        'repositories/settings_repository.dart'
    ],
    'setup': [
        'screens/setup/wifi_setup_screen.dart',
        'services/esp_api_service.dart'
    ],
    'notifications': [
        'screens/notification_history_screen.dart',
        'utils/notification_helper.dart',
        'widgets/notification_badge.dart'
    ],
    'onboarding': [
        'screens/onboarding_screen.dart',
        'screens/splash_screen.dart'
    ],
    'core': [
        'models/smart_config.dart',
        'providers/mqtt_provider.dart',
        'providers/mqtt_provider.g.dart',
        'providers/theme_provider.dart',
        'providers/theme_provider.g.dart',
        'repositories/firestore_repository.dart',
        'repositories/mqtt_repository.dart',
        'services/logger_service.dart',
        'services/session_manager.dart',
        'utils/constants.dart',
        'utils/haptic_helper.dart',
        'utils/helpers.dart',
        'utils/localization_extension.dart',
        'utils/reauth_helper.dart',
        'utils/toast_helper.dart',
        'widgets/bouncing_button.dart',
        'widgets/loading_overlay.dart',
        'widgets/premium_dialog.dart',
        'widgets/user_avatar.dart',
        'widgets/animations/dual_layer_screen_wrapper.dart',
        'widgets/animations/wave_background.dart'
    ]
}

def create_feature_dirs():
    os.makedirs(FEATURES_DIR, exist_ok=True)
    for feature in file_mapping.keys():
        os.makedirs(os.path.join(FEATURES_DIR, feature, 'ui'), exist_ok=True)
        os.makedirs(os.path.join(FEATURES_DIR, feature, 'logic'), exist_ok=True)
        os.makedirs(os.path.join(FEATURES_DIR, feature, 'data'), exist_ok=True)

def determine_subfolder(file_path):
    if 'providers/' in file_path or 'mixins/' in file_path or 'utils/' in file_path or 'services/' in file_path:
        return 'logic'
    elif 'repositories/' in file_path or 'models/' in file_path:
        return 'data'
    else:
        return 'ui'

def move_files():
    moves = []
    for feature, files in file_mapping.items():
        for file in files:
            src = os.path.join(BASE_DIR, file)
            if not os.path.exists(src):
                print(f"Warning: {src} does not exist.")
                continue
            
            subfolder = determine_subfolder(file)
            filename = os.path.basename(file)
            dest = os.path.join(FEATURES_DIR, feature, subfolder, filename)
            
            moves.append((src, dest))
            shutil.move(src, dest)
            print(f"Moved {file} to {dest}")
    return moves

def fix_imports():
    # Because fixing all imports automatically in python is hard, we can use a simpler approach:
    # 1. Gather all new paths
    # 2. For every file, find imports and replace them with correct relative imports
    pass

if __name__ == '__main__':
    create_feature_dirs()
    move_files()
    print("Files moved successfully.")
