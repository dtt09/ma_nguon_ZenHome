import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @greeting_morning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greeting_morning;

  /// No description provided for @greeting_afternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greeting_afternoon;

  /// No description provided for @greeting_evening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greeting_evening;

  /// No description provided for @my_home.
  ///
  /// In en, this message translates to:
  /// **'My Home'**
  String get my_home;

  /// No description provided for @weather.
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get weather;

  /// No description provided for @room_1.
  ///
  /// In en, this message translates to:
  /// **'Living Room'**
  String get room_1;

  /// No description provided for @room_2.
  ///
  /// In en, this message translates to:
  /// **'Bedroom'**
  String get room_2;

  /// No description provided for @room_3.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get room_3;

  /// No description provided for @room_4.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get room_4;

  /// No description provided for @device_1.
  ///
  /// In en, this message translates to:
  /// **'Main Light'**
  String get device_1;

  /// No description provided for @device_2.
  ///
  /// In en, this message translates to:
  /// **'Ceiling Fan'**
  String get device_2;

  /// No description provided for @device_3.
  ///
  /// In en, this message translates to:
  /// **'Night Light'**
  String get device_3;

  /// No description provided for @status_on.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get status_on;

  /// No description provided for @status_off.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get status_off;

  /// No description provided for @tab_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tab_home;

  /// No description provided for @tab_scene.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get tab_scene;

  /// No description provided for @tab_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tab_settings;

  /// No description provided for @setting_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setting_title;

  /// No description provided for @theme_mode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme_mode;

  /// No description provided for @theme_system.
  ///
  /// In en, this message translates to:
  /// **'System (Auto)'**
  String get theme_system;

  /// No description provided for @theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get theme_light;

  /// No description provided for @theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get theme_dark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @profile_title.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profile_title;

  /// No description provided for @family_members.
  ///
  /// In en, this message translates to:
  /// **'Family Members'**
  String get family_members;

  /// No description provided for @setup_wifi.
  ///
  /// In en, this message translates to:
  /// **'Setup Device Wi-Fi'**
  String get setup_wifi;

  /// No description provided for @tech_area.
  ///
  /// In en, this message translates to:
  /// **'Technical Area'**
  String get tech_area;

  /// No description provided for @btn_logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get btn_logout;

  /// No description provided for @general_settings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get general_settings;

  /// No description provided for @system_settings.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system_settings;

  /// No description provided for @update_avatar.
  ///
  /// In en, this message translates to:
  /// **'Update Avatar'**
  String get update_avatar;

  /// No description provided for @enter_image_url.
  ///
  /// In en, this message translates to:
  /// **'Enter image URL...'**
  String get enter_image_url;

  /// No description provided for @btn_save_image.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get btn_save_image;

  /// No description provided for @basic_info.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basic_info;

  /// No description provided for @display_name.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get display_name;

  /// No description provided for @change_password.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get change_password;

  /// No description provided for @old_password.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get old_password;

  /// No description provided for @new_password.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get new_password;

  /// No description provided for @confirm_new_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirm_new_password;

  /// No description provided for @btn_save_changes.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get btn_save_changes;

  /// No description provided for @err_empty_old_pass.
  ///
  /// In en, this message translates to:
  /// **'Please enter current password!'**
  String get err_empty_old_pass;

  /// No description provided for @err_short_new_pass.
  ///
  /// In en, this message translates to:
  /// **'New password must be at least 6 characters!'**
  String get err_short_new_pass;

  /// No description provided for @err_wrong_old_pass.
  ///
  /// In en, this message translates to:
  /// **'Incorrect current password!'**
  String get err_wrong_old_pass;

  /// No description provided for @msg_avatar_updated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated successfully!'**
  String get msg_avatar_updated;

  /// No description provided for @msg_profile_updated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get msg_profile_updated;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @login_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your life, connect your future.'**
  String get login_subtitle;

  /// No description provided for @email_label.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get email_label;

  /// No description provided for @password_label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password_label;

  /// No description provided for @forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgot_password;

  /// No description provided for @btn_login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get btn_login;

  /// No description provided for @or_divider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or_divider;

  /// No description provided for @continue_with_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continue_with_google;

  /// No description provided for @no_account.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get no_account;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @register_prompt.
  ///
  /// In en, this message translates to:
  /// **'This email does not seem to be registered. Do you want to create a new account?'**
  String get register_prompt;

  /// No description provided for @register_title.
  ///
  /// In en, this message translates to:
  /// **'Create New Account'**
  String get register_title;

  /// No description provided for @register_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your home, your rules.'**
  String get register_subtitle;

  /// No description provided for @btn_register.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get btn_register;

  /// No description provided for @have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get have_account;

  /// No description provided for @security_title.
  ///
  /// In en, this message translates to:
  /// **'Account Security'**
  String get security_title;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting:'**
  String get connecting;

  /// No description provided for @google_pass_msg.
  ///
  /// In en, this message translates to:
  /// **'Even with Google, you need to set a password for secure management.'**
  String get google_pass_msg;

  /// No description provided for @create_password.
  ///
  /// In en, this message translates to:
  /// **'Create password'**
  String get create_password;

  /// No description provided for @confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirm_password;

  /// No description provided for @btn_confirm_enter.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Enter'**
  String get btn_confirm_enter;

  /// No description provided for @btn_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get btn_continue;

  /// No description provided for @forgot_desc.
  ///
  /// In en, this message translates to:
  /// **'Enter your email, we will send a link to reset your password.'**
  String get forgot_desc;

  /// No description provided for @send_reset_link.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get send_reset_link;

  /// No description provided for @err_invalid_login.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password!'**
  String get err_invalid_login;

  /// No description provided for @err_generic.
  ///
  /// In en, this message translates to:
  /// **'An error occurred, please try again!'**
  String get err_generic;

  /// No description provided for @msg_reset_link_sent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent. Please check your email!'**
  String get msg_reset_link_sent;

  /// No description provided for @err_email_req.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email!'**
  String get err_email_req;

  /// No description provided for @scene_title.
  ///
  /// In en, this message translates to:
  /// **'Smart Scenes'**
  String get scene_title;

  /// No description provided for @scene_empty.
  ///
  /// In en, this message translates to:
  /// **'No scenes available'**
  String get scene_empty;

  /// No description provided for @scene_leave.
  ///
  /// In en, this message translates to:
  /// **'Leave Home'**
  String get scene_leave;

  /// No description provided for @scene_home.
  ///
  /// In en, this message translates to:
  /// **'Arrive Home'**
  String get scene_home;

  /// No description provided for @scene_sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep Mode'**
  String get scene_sleep;

  /// No description provided for @tip_scene.
  ///
  /// In en, this message translates to:
  /// **'💡 Tip: Long press a Scene to reorder'**
  String get tip_scene;

  /// No description provided for @scene_options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get scene_options;

  /// No description provided for @scene_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Scene'**
  String get scene_edit;

  /// No description provided for @scene_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete Scene'**
  String get scene_delete;

  /// No description provided for @scene_activated.
  ///
  /// In en, this message translates to:
  /// **'Activated:'**
  String get scene_activated;

  /// No description provided for @scene_create.
  ///
  /// In en, this message translates to:
  /// **'Create New Scene'**
  String get scene_create;

  /// No description provided for @scene_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Scene Name (e.g., Movie Time)'**
  String get scene_name_hint;

  /// No description provided for @select_icon.
  ///
  /// In en, this message translates to:
  /// **'Select Icon'**
  String get select_icon;

  /// No description provided for @set_actions.
  ///
  /// In en, this message translates to:
  /// **'Set Actions'**
  String get set_actions;

  /// No description provided for @action_ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get action_ignore;

  /// No description provided for @action_on.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get action_on;

  /// No description provided for @action_off.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get action_off;

  /// No description provided for @btn_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btn_save;

  /// No description provided for @err_empty_name.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Please enter a scene name!'**
  String get err_empty_name;

  /// No description provided for @err_no_action.
  ///
  /// In en, this message translates to:
  /// **'⚠️ You must set ON/OFF for at least 1 device!'**
  String get err_no_action;

  /// No description provided for @msg_saved_title.
  ///
  /// In en, this message translates to:
  /// **'Saved Successfully'**
  String get msg_saved_title;

  /// No description provided for @msg_saved_desc.
  ///
  /// In en, this message translates to:
  /// **'Scene configuration has been saved.'**
  String get msg_saved_desc;

  /// No description provided for @timer_title.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer_title;

  /// No description provided for @timer_action_off.
  ///
  /// In en, this message translates to:
  /// **'Turn OFF after (Currently ON)'**
  String get timer_action_off;

  /// No description provided for @timer_action_on.
  ///
  /// In en, this message translates to:
  /// **'Turn ON after (Currently OFF)'**
  String get timer_action_on;

  /// No description provided for @timer_start.
  ///
  /// In en, this message translates to:
  /// **'Start Timer'**
  String get timer_start;

  /// No description provided for @timer_history.
  ///
  /// In en, this message translates to:
  /// **'Timer History'**
  String get timer_history;

  /// No description provided for @clear_history.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clear_history;

  /// No description provided for @canceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get canceled;

  /// No description provided for @cancel_cmd.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel_cmd;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @schedule_title.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get schedule_title;

  /// No description provided for @schedule_empty.
  ///
  /// In en, this message translates to:
  /// **'No schedules yet'**
  String get schedule_empty;

  /// No description provided for @schedule_add.
  ///
  /// In en, this message translates to:
  /// **'Add New Schedule'**
  String get schedule_add;

  /// No description provided for @schedule_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Schedule'**
  String get schedule_edit;

  /// No description provided for @schedule_turn_on.
  ///
  /// In en, this message translates to:
  /// **'TURN ON AT'**
  String get schedule_turn_on;

  /// No description provided for @schedule_turn_off.
  ///
  /// In en, this message translates to:
  /// **'TURN OFF AT'**
  String get schedule_turn_off;

  /// No description provided for @schedule_repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get schedule_repeat;

  /// No description provided for @schedule_save.
  ///
  /// In en, this message translates to:
  /// **'Save Schedule'**
  String get schedule_save;

  /// No description provided for @err_select_day.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Please select at least one day!'**
  String get err_select_day;

  /// No description provided for @err_conflict.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Time conflict with an existing schedule!'**
  String get err_conflict;

  /// No description provided for @msg_schedule_saved.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved successfully'**
  String get msg_schedule_saved;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mo'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tu'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'We'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Th'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fr'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sa'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Su'**
  String get sun;

  /// No description provided for @msg_deleted_title.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get msg_deleted_title;

  /// No description provided for @msg_schedule_deleted_desc.
  ///
  /// In en, this message translates to:
  /// **'Schedule has been removed from the system.'**
  String get msg_schedule_deleted_desc;

  /// No description provided for @status_connected.
  ///
  /// In en, this message translates to:
  /// **'Home Connected'**
  String get status_connected;

  /// No description provided for @status_disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get status_disconnected;

  /// No description provided for @status_reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get status_reconnect;

  /// No description provided for @msg_reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to server...'**
  String get msg_reconnecting;

  /// No description provided for @temp_indoor.
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get temp_indoor;

  /// No description provided for @temp_outdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get temp_outdoor;

  /// No description provided for @fetching_gps.
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get fetching_gps;

  /// No description provided for @toast_success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get toast_success;

  /// No description provided for @toast_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get toast_error;

  /// No description provided for @toast_turn_on.
  ///
  /// In en, this message translates to:
  /// **'Device turned ON!'**
  String get toast_turn_on;

  /// No description provided for @toast_turn_off.
  ///
  /// In en, this message translates to:
  /// **'Device turned OFF!'**
  String get toast_turn_off;

  /// No description provided for @toast_mqtt_wait.
  ///
  /// In en, this message translates to:
  /// **'Please wait, connecting to network!'**
  String get toast_mqtt_wait;

  /// No description provided for @toast_activated.
  ///
  /// In en, this message translates to:
  /// **'Scene activated'**
  String get toast_activated;

  /// No description provided for @toast_sys_report.
  ///
  /// In en, this message translates to:
  /// **'System Report'**
  String get toast_sys_report;

  /// No description provided for @toast_timer_title.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get toast_timer_title;

  /// No description provided for @toast_timer_set.
  ///
  /// In en, this message translates to:
  /// **'Timer set successfully!'**
  String get toast_timer_set;

  /// No description provided for @toast_timer_cancel.
  ///
  /// In en, this message translates to:
  /// **'Timer canceled!'**
  String get toast_timer_cancel;

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'Zen Home'**
  String get app_title;

  /// No description provided for @no_device.
  ///
  /// In en, this message translates to:
  /// **'No devices available.'**
  String get no_device;

  /// No description provided for @gps_disabled.
  ///
  /// In en, this message translates to:
  /// **'GPS is disabled'**
  String get gps_disabled;

  /// No description provided for @gps_denied.
  ///
  /// In en, this message translates to:
  /// **'GPS permission denied'**
  String get gps_denied;

  /// No description provided for @gps_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown location'**
  String get gps_unknown;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confirm_title;

  /// No description provided for @confirm_delete_timer.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this timer?'**
  String get confirm_delete_timer;

  /// No description provided for @confirm_delete_schedule.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this schedule?'**
  String get confirm_delete_schedule;

  /// No description provided for @btn_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btn_cancel;

  /// No description provided for @btn_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get btn_delete;

  /// No description provided for @hard_disconnect_title.
  ///
  /// In en, this message translates to:
  /// **'Connection Lost'**
  String get hard_disconnect_title;

  /// No description provided for @hard_disconnect_desc.
  ///
  /// In en, this message translates to:
  /// **'The connection timed out. Please check your network and try again.'**
  String get hard_disconnect_desc;

  /// No description provided for @btn_retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get btn_retry;

  /// No description provided for @admin_login_title.
  ///
  /// In en, this message translates to:
  /// **'Technical Area'**
  String get admin_login_title;

  /// No description provided for @admin_login_desc.
  ///
  /// In en, this message translates to:
  /// **'Please enter admin password'**
  String get admin_login_desc;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @admin_pass_incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password!'**
  String get admin_pass_incorrect;

  /// No description provided for @btn_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get btn_confirm;

  /// No description provided for @admin_mapping_title.
  ///
  /// In en, this message translates to:
  /// **'Admin: Relay Management'**
  String get admin_mapping_title;

  /// No description provided for @tooltip_save_sync.
  ///
  /// In en, this message translates to:
  /// **'Save & Sync'**
  String get tooltip_save_sync;

  /// No description provided for @btn_add_device.
  ///
  /// In en, this message translates to:
  /// **'Add New Device'**
  String get btn_add_device;

  /// No description provided for @edit_relay.
  ///
  /// In en, this message translates to:
  /// **'Edit Relay'**
  String get edit_relay;

  /// No description provided for @add_relay.
  ///
  /// In en, this message translates to:
  /// **'Add New Relay'**
  String get add_relay;

  /// No description provided for @dev_id_hint.
  ///
  /// In en, this message translates to:
  /// **'Device ID (e.g., relay_1)'**
  String get dev_id_hint;

  /// No description provided for @dev_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Display Name (e.g., Main Light)'**
  String get dev_name_hint;

  /// No description provided for @gpio_hint.
  ///
  /// In en, this message translates to:
  /// **'GPIO Pin on ESP32 (e.g., 4)'**
  String get gpio_hint;

  /// No description provided for @room_hint.
  ///
  /// In en, this message translates to:
  /// **'Assign to Room'**
  String get room_hint;

  /// No description provided for @choose_icon.
  ///
  /// In en, this message translates to:
  /// **'Choose Icon:'**
  String get choose_icon;

  /// No description provided for @btn_update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get btn_update;

  /// No description provided for @err_empty_field.
  ///
  /// In en, this message translates to:
  /// **'Cannot be empty'**
  String get err_empty_field;

  /// No description provided for @err_need_device.
  ///
  /// In en, this message translates to:
  /// **'At least 1 device is required!'**
  String get err_need_device;

  /// No description provided for @msg_sync_offline.
  ///
  /// In en, this message translates to:
  /// **'Cloud not connected, saved offline!'**
  String get msg_sync_offline;

  /// No description provided for @wifi_setup_title.
  ///
  /// In en, this message translates to:
  /// **'Device Wi-Fi Setup'**
  String get wifi_setup_title;

  /// No description provided for @wifi_setup_desc.
  ///
  /// In en, this message translates to:
  /// **'Please connect your phone to the \"ZenHome_Setup\" Wi-Fi network emitted by the device.'**
  String get wifi_setup_desc;

  /// No description provided for @wifi_ssid.
  ///
  /// In en, this message translates to:
  /// **'Your Home Wi-Fi (SSID)'**
  String get wifi_ssid;

  /// No description provided for @wifi_ssid_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter exact Wi-Fi name'**
  String get wifi_ssid_hint;

  /// No description provided for @wifi_pass.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Password'**
  String get wifi_pass;

  /// No description provided for @wifi_pass_hint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if no password'**
  String get wifi_pass_hint;

  /// No description provided for @admin_pass_opt.
  ///
  /// In en, this message translates to:
  /// **'Admin Password (Optional)'**
  String get admin_pass_opt;

  /// No description provided for @admin_pass_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter pass for future access'**
  String get admin_pass_hint;

  /// No description provided for @confirm_admin_pass.
  ///
  /// In en, this message translates to:
  /// **'Confirm Admin Password'**
  String get confirm_admin_pass;

  /// No description provided for @confirm_admin_pass_hint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter admin password'**
  String get confirm_admin_pass_hint;

  /// No description provided for @mqtt_server_address.
  ///
  /// In en, this message translates to:
  /// **'MQTT Server Address'**
  String get mqtt_server_address;

  /// No description provided for @mqtt_server_hint.
  ///
  /// In en, this message translates to:
  /// **'e164fa...hivemq.cloud'**
  String get mqtt_server_hint;

  /// No description provided for @btn_pump_config.
  ///
  /// In en, this message translates to:
  /// **'Push Configuration to Device'**
  String get btn_pump_config;

  /// No description provided for @add_new_member.
  ///
  /// In en, this message translates to:
  /// **'Add New Member:'**
  String get add_new_member;

  /// No description provided for @email_receiver_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter recipient Email'**
  String get email_receiver_hint;

  /// No description provided for @linked_list.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts:'**
  String get linked_list;

  /// No description provided for @empty_member.
  ///
  /// In en, this message translates to:
  /// **'No members found.'**
  String get empty_member;

  /// No description provided for @new_invite.
  ///
  /// In en, this message translates to:
  /// **'New Home Invitation:'**
  String get new_invite;

  /// No description provided for @invite_desc.
  ///
  /// In en, this message translates to:
  /// **'Invited you to co-manage home'**
  String get invite_desc;

  /// No description provided for @err_invalid_email.
  ///
  /// In en, this message translates to:
  /// **'Invalid Email!'**
  String get err_invalid_email;

  /// No description provided for @err_self_invite.
  ///
  /// In en, this message translates to:
  /// **'Cannot invite yourself!'**
  String get err_self_invite;

  /// No description provided for @err_pass_mismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match!'**
  String get err_pass_mismatch;

  /// No description provided for @msg_send_success.
  ///
  /// In en, this message translates to:
  /// **'Authorization sent to'**
  String get msg_send_success;

  /// No description provided for @invite_title.
  ///
  /// In en, this message translates to:
  /// **'Home Invitation'**
  String get invite_title;

  /// No description provided for @invite_body.
  ///
  /// In en, this message translates to:
  /// **'has invited you to join and control their home. Open the app to respond!'**
  String get invite_body;

  /// No description provided for @msg_processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get msg_processing;

  /// No description provided for @msg_syncing_home.
  ///
  /// In en, this message translates to:
  /// **'Syncing home data from'**
  String get msg_syncing_home;

  /// No description provided for @msg_sync_success.
  ///
  /// In en, this message translates to:
  /// **'Sync complete! Welcome to the new home.'**
  String get msg_sync_success;

  /// No description provided for @msg_reject_success.
  ///
  /// In en, this message translates to:
  /// **'Declined invitation from'**
  String get msg_reject_success;

  /// No description provided for @msg_revoke_success.
  ///
  /// In en, this message translates to:
  /// **'Revoked access of'**
  String get msg_revoke_success;

  /// No description provided for @msg_confirm_revoke.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to revoke access of\n\n{email}\n\nThis person will be immediately removed from the home.'**
  String msg_confirm_revoke(String email);

  /// No description provided for @btn_revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke Access'**
  String get btn_revoke;

  /// No description provided for @err_wifi_empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your Wi-Fi name'**
  String get err_wifi_empty;

  /// No description provided for @msg_pump_success.
  ///
  /// In en, this message translates to:
  /// **'Configuration pushed to device successfully!'**
  String get msg_pump_success;

  /// No description provided for @err_pump_fail.
  ///
  /// In en, this message translates to:
  /// **'Device not found, make sure you are connected to its Wi-Fi!'**
  String get err_pump_fail;

  /// No description provided for @mqtt_user.
  ///
  /// In en, this message translates to:
  /// **'MQTT Username (Optional)'**
  String get mqtt_user;

  /// No description provided for @mqtt_user_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter MQTT Username'**
  String get mqtt_user_hint;

  /// No description provided for @mqtt_pass.
  ///
  /// In en, this message translates to:
  /// **'MQTT Password (Optional)'**
  String get mqtt_pass;

  /// No description provided for @mqtt_pass_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter MQTT Password'**
  String get mqtt_pass_hint;

  /// No description provided for @onboarding_title_1.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ZenHome'**
  String get onboarding_title_1;

  /// No description provided for @onboarding_desc_1.
  ///
  /// In en, this message translates to:
  /// **'Control all your smart devices from one place.'**
  String get onboarding_desc_1;

  /// No description provided for @onboarding_title_2.
  ///
  /// In en, this message translates to:
  /// **'Automate Your Life'**
  String get onboarding_title_2;

  /// No description provided for @onboarding_desc_2.
  ///
  /// In en, this message translates to:
  /// **'Create scenes and schedules to fit your lifestyle.'**
  String get onboarding_desc_2;

  /// No description provided for @onboarding_title_3.
  ///
  /// In en, this message translates to:
  /// **'Stay Notified'**
  String get onboarding_title_3;

  /// No description provided for @onboarding_desc_3.
  ///
  /// In en, this message translates to:
  /// **'Get real-time alerts and track your device history.'**
  String get onboarding_desc_3;

  /// No description provided for @btn_get_started.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get btn_get_started;

  /// No description provided for @btn_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get btn_next;

  /// No description provided for @btn_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get btn_skip;

  /// No description provided for @notification_history_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notification_history_title;

  /// No description provided for @no_notifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get no_notifications;

  /// No description provided for @clear_all.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clear_all;

  /// No description provided for @logout_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logout_confirm_desc;

  /// No description provided for @clear_history_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all notification history?'**
  String get clear_history_confirm;

  /// No description provided for @btn_yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get btn_yes;

  /// No description provided for @btn_no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get btn_no;

  /// No description provided for @msg_kicked.
  ///
  /// In en, this message translates to:
  /// **'Your access has been revoked by the owner!'**
  String get msg_kicked;

  /// No description provided for @home_of.
  ///
  /// In en, this message translates to:
  /// **'Home of'**
  String get home_of;

  /// No description provided for @my_home_default.
  ///
  /// In en, this message translates to:
  /// **'My Home'**
  String get my_home_default;

  /// No description provided for @err_firebase_weak_password.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak, must be over 6 characters!'**
  String get err_firebase_weak_password;

  /// No description provided for @err_firebase_email_in_use.
  ///
  /// In en, this message translates to:
  /// **'Email is already in use!'**
  String get err_firebase_email_in_use;

  /// No description provided for @err_firebase_invalid_email.
  ///
  /// In en, this message translates to:
  /// **'Invalid Email format!'**
  String get err_firebase_invalid_email;

  /// No description provided for @default_device_name.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get default_device_name;

  /// No description provided for @device_mapping_info.
  ///
  /// In en, this message translates to:
  /// **'ID: {id} | GPIO {pin}'**
  String device_mapping_info(String id, String pin);

  /// No description provided for @status_waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get status_waiting;

  /// No description provided for @notification_channel_desc.
  ///
  /// In en, this message translates to:
  /// **'Notification channel for Zen Home'**
  String get notification_channel_desc;

  /// No description provided for @notification_channel_name.
  ///
  /// In en, this message translates to:
  /// **'Zen Home Notifications'**
  String get notification_channel_name;

  /// No description provided for @err_user_not_found.
  ///
  /// In en, this message translates to:
  /// **'Account does not exist in the system. Please check again.'**
  String get err_user_not_found;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @important.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get important;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @action.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get action;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @splash_subtitle.
  ///
  /// In en, this message translates to:
  /// **'One touch, all-day comfort.'**
  String get splash_subtitle;

  /// No description provided for @scenes_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a scene to quickly trigger a set of actions.'**
  String get scenes_subtitle;

  /// No description provided for @share_with_all.
  ///
  /// In en, this message translates to:
  /// **'Share with everyone?'**
  String get share_with_all;

  /// No description provided for @shared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get shared;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @switch_home.
  ///
  /// In en, this message translates to:
  /// **'Switch Home'**
  String get switch_home;

  /// No description provided for @no_home_to_switch.
  ///
  /// In en, this message translates to:
  /// **'No home available to switch'**
  String get no_home_to_switch;

  /// No description provided for @select_device.
  ///
  /// In en, this message translates to:
  /// **'Select device'**
  String get select_device;

  /// No description provided for @welcome_back.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcome_back;

  /// No description provided for @use_other_account.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get use_other_account;

  /// No description provided for @verify_email_title.
  ///
  /// In en, this message translates to:
  /// **'Email Verification'**
  String get verify_email_title;

  /// No description provided for @verify_email_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit OTP code sent to your email.'**
  String get verify_email_subtitle;

  /// No description provided for @enter_otp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enter_otp;

  /// No description provided for @didnt_receive_code.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive code?'**
  String get didnt_receive_code;

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend;

  /// No description provided for @btn_verify.
  ///
  /// In en, this message translates to:
  /// **'Verify & Login'**
  String get btn_verify;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get loading;

  /// No description provided for @phone_number.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phone_number;

  /// No description provided for @register_now.
  ///
  /// In en, this message translates to:
  /// **'Register now'**
  String get register_now;

  /// No description provided for @err_empty_phone_forgot.
  ///
  /// In en, this message translates to:
  /// **'Please enter your Phone number or Email above to reset password!'**
  String get err_empty_phone_forgot;

  /// No description provided for @err_phone_not_registered.
  ///
  /// In en, this message translates to:
  /// **'This phone number is not registered!'**
  String get err_phone_not_registered;

  /// No description provided for @err_send_otp.
  ///
  /// In en, this message translates to:
  /// **'Error sending OTP'**
  String get err_send_otp;

  /// No description provided for @register_account.
  ///
  /// In en, this message translates to:
  /// **'Register Account'**
  String get register_account;

  /// No description provided for @enter_phone_continue.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number to continue'**
  String get enter_phone_continue;

  /// No description provided for @err_phone_already_registered.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already registered!'**
  String get err_phone_already_registered;

  /// No description provided for @send_otp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get send_otp;

  /// No description provided for @verify_otp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verify_otp;

  /// No description provided for @otp_sent_to.
  ///
  /// In en, this message translates to:
  /// **'An OTP has been sent to'**
  String get otp_sent_to;

  /// No description provided for @enter_6_digit_otp.
  ///
  /// In en, this message translates to:
  /// **'Please check your messages and enter the 6-digit code'**
  String get enter_6_digit_otp;

  /// No description provided for @did_not_receive_otp.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code?'**
  String get did_not_receive_otp;

  /// No description provided for @resend_otp.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resend_otp;

  /// No description provided for @resend_otp_in.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String resend_otp_in(String seconds);

  /// No description provided for @btn_verify_otp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get btn_verify_otp;

  /// No description provided for @err_invalid_otp.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired OTP code!'**
  String get err_invalid_otp;

  /// No description provided for @create_account.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get create_account;

  /// No description provided for @complete_info.
  ///
  /// In en, this message translates to:
  /// **'Complete your information to start using ZenHome.'**
  String get complete_info;

  /// No description provided for @username_label.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username_label;

  /// No description provided for @username_hint.
  ///
  /// In en, this message translates to:
  /// **'Example: thuat-dev-01'**
  String get username_hint;

  /// No description provided for @err_invalid_username.
  ///
  /// In en, this message translates to:
  /// **'Username must be continuous without accents, and may contain dashes or underscores.'**
  String get err_invalid_username;

  /// No description provided for @err_username_in_use.
  ///
  /// In en, this message translates to:
  /// **'This username is already in use. Please choose another one!'**
  String get err_username_in_use;

  /// No description provided for @err_phone_pass_conflict.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already registered and you entered the wrong password.'**
  String get err_phone_pass_conflict;

  /// No description provided for @forgot_password_desc.
  ///
  /// In en, this message translates to:
  /// **'Please enter your registered Phone number or Email to recover your password.'**
  String get forgot_password_desc;

  /// No description provided for @reset_password_title.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get reset_password_title;

  /// No description provided for @reset_password_desc.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password for your account.'**
  String get reset_password_desc;

  /// No description provided for @update_password.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get update_password;

  /// No description provided for @password_updated_success.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully!'**
  String get password_updated_success;

  /// No description provided for @phone_or_email.
  ///
  /// In en, this message translates to:
  /// **'Phone number / Email'**
  String get phone_or_email;

  /// No description provided for @err_not_linked_esp32.
  ///
  /// In en, this message translates to:
  /// **'The account is not linked to any ESP32 device.'**
  String get err_not_linked_esp32;

  /// No description provided for @btn_link_now.
  ///
  /// In en, this message translates to:
  /// **'Link now'**
  String get btn_link_now;

  /// No description provided for @account_not_registered.
  ///
  /// In en, this message translates to:
  /// **'Account not registered'**
  String get account_not_registered;

  /// No description provided for @ask_register_google.
  ///
  /// In en, this message translates to:
  /// **'This account is not registered. Do you want to register an account with {email}?'**
  String ask_register_google(String email);

  /// No description provided for @req_min_length.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get req_min_length;

  /// No description provided for @req_uppercase.
  ///
  /// In en, this message translates to:
  /// **'Uppercase letter'**
  String get req_uppercase;

  /// No description provided for @req_lowercase.
  ///
  /// In en, this message translates to:
  /// **'Lowercase letter'**
  String get req_lowercase;

  /// No description provided for @req_number.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get req_number;

  /// No description provided for @req_special_char.
  ///
  /// In en, this message translates to:
  /// **'Special character (!@#\$%^&*)'**
  String get req_special_char;

  /// No description provided for @or_login_with.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or_login_with;

  /// No description provided for @msg_otp_resent.
  ///
  /// In en, this message translates to:
  /// **'OTP code resent!'**
  String get msg_otp_resent;

  /// No description provided for @menu_account_info.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get menu_account_info;

  /// No description provided for @menu_change_password.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get menu_change_password;

  /// No description provided for @menu_logged_devices.
  ///
  /// In en, this message translates to:
  /// **'Logged-in Devices'**
  String get menu_logged_devices;

  /// No description provided for @menu_linked_accounts.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get menu_linked_accounts;

  /// No description provided for @menu_delete_account.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get menu_delete_account;

  /// No description provided for @msg_confirm_delete_account.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? Data cannot be recovered.'**
  String get msg_confirm_delete_account;

  /// No description provided for @title_linked_accounts.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get title_linked_accounts;

  /// No description provided for @title_logged_devices.
  ///
  /// In en, this message translates to:
  /// **'Active Devices'**
  String get title_logged_devices;

  /// No description provided for @msg_no_other_devices.
  ///
  /// In en, this message translates to:
  /// **'No other devices are currently logged in.'**
  String get msg_no_other_devices;

  /// No description provided for @btn_unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get btn_unlink;

  /// No description provided for @btn_link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get btn_link;

  /// No description provided for @security_alert_title.
  ///
  /// In en, this message translates to:
  /// **'Security Alert'**
  String get security_alert_title;

  /// No description provided for @new_login_msg.
  ///
  /// In en, this message translates to:
  /// **'A new device ({deviceName}) just logged into your account from {location}.'**
  String new_login_msg(String deviceName, String location);

  /// No description provided for @trust_req_title.
  ///
  /// In en, this message translates to:
  /// **'Trust Request'**
  String get trust_req_title;

  /// No description provided for @trust_req_msg.
  ///
  /// In en, this message translates to:
  /// **'Device \"{deviceName}\" is requesting Trusted access. Do you allow?'**
  String trust_req_msg(String deviceName);

  /// No description provided for @btn_refuse.
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get btn_refuse;

  /// No description provided for @btn_agree.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get btn_agree;

  /// No description provided for @msg_success_title.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get msg_success_title;

  /// No description provided for @msg_trusted_success.
  ///
  /// In en, this message translates to:
  /// **'Trusted access granted to {deviceName}'**
  String msg_trusted_success(String deviceName);

  /// No description provided for @msg_error_title.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get msg_error_title;

  /// No description provided for @msg_trust_error.
  ///
  /// In en, this message translates to:
  /// **'Cannot grant access'**
  String get msg_trust_error;

  /// No description provided for @unknown_device.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknown_device;

  /// No description provided for @unknown_location.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown_location;

  /// No description provided for @birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthday;

  /// No description provided for @contact_info.
  ///
  /// In en, this message translates to:
  /// **'Contact Info'**
  String get contact_info;

  /// No description provided for @btn_change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get btn_change;

  /// No description provided for @reauth_sms_title.
  ///
  /// In en, this message translates to:
  /// **'Re-authenticate via SMS'**
  String get reauth_sms_title;

  /// No description provided for @reauth_sending_otp.
  ///
  /// In en, this message translates to:
  /// **'Sending OTP to your phone number...'**
  String get reauth_sending_otp;

  /// No description provided for @reauth_enter_otp_msg.
  ///
  /// In en, this message translates to:
  /// **'Please enter the OTP just sent to {phone}.'**
  String reauth_enter_otp_msg(String phone);

  /// No description provided for @reauth_title.
  ///
  /// In en, this message translates to:
  /// **'Re-authenticate'**
  String get reauth_title;

  /// No description provided for @reauth_reason_msg.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password to {reason}.'**
  String reauth_reason_msg(String reason);

  /// No description provided for @err_reauth_google_failed.
  ///
  /// In en, this message translates to:
  /// **'Google re-authentication failed'**
  String get err_reauth_google_failed;

  /// No description provided for @err_send_otp_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP: {error}'**
  String err_send_otp_failed(String error);

  /// No description provided for @err_invalid_otp_code.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP code'**
  String get err_invalid_otp_code;

  /// No description provided for @err_empty_password.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get err_empty_password;

  /// No description provided for @err_wrong_password.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get err_wrong_password;

  /// No description provided for @final_warning.
  ///
  /// In en, this message translates to:
  /// **'Final Warning'**
  String get final_warning;

  /// No description provided for @delete_account_warning.
  ///
  /// In en, this message translates to:
  /// **'This action CANNOT be undone. All smart home data will be permanently deleted.\n\nDo you still want to proceed?'**
  String get delete_account_warning;

  /// No description provided for @btn_still_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete anyway'**
  String get btn_still_delete;

  /// No description provided for @err_trusted_device_only_delete.
  ///
  /// In en, this message translates to:
  /// **'You can only delete your account from a Trusted Device'**
  String get err_trusted_device_only_delete;

  /// No description provided for @register_review_info.
  ///
  /// In en, this message translates to:
  /// **'Please review the following information before creating an account:'**
  String get register_review_info;

  /// No description provided for @full_name_label.
  ///
  /// In en, this message translates to:
  /// **'Full Name:'**
  String get full_name_label;

  /// No description provided for @username_label_full.
  ///
  /// In en, this message translates to:
  /// **'Username:'**
  String get username_label_full;

  /// No description provided for @phone_label.
  ///
  /// In en, this message translates to:
  /// **'Phone number:'**
  String get phone_label;

  /// No description provided for @google_linked.
  ///
  /// In en, this message translates to:
  /// **'Google Linked: Verified'**
  String get google_linked;

  /// No description provided for @btn_edit_info.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get btn_edit_info;

  /// No description provided for @logout_device_title.
  ///
  /// In en, this message translates to:
  /// **'Log out device'**
  String get logout_device_title;

  /// No description provided for @btn_kick_device.
  ///
  /// In en, this message translates to:
  /// **'Kick out'**
  String get btn_kick_device;

  /// No description provided for @this_device.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get this_device;

  /// No description provided for @last_access.
  ///
  /// In en, this message translates to:
  /// **'Last access:'**
  String get last_access;

  /// No description provided for @msg_kick_success.
  ///
  /// In en, this message translates to:
  /// **'Device kicked out successfully!'**
  String get msg_kick_success;

  /// No description provided for @err_kick_failed.
  ///
  /// In en, this message translates to:
  /// **'Error kicking out device: {error}'**
  String err_kick_failed(String error);

  /// No description provided for @msg_trust_req_sent.
  ///
  /// In en, this message translates to:
  /// **'Trust request sent successfully!'**
  String get msg_trust_req_sent;

  /// No description provided for @err_trust_req_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send trust request'**
  String get err_trust_req_failed;

  /// No description provided for @btn_confirm_update.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Update'**
  String get btn_confirm_update;

  /// No description provided for @msg_kicked_desc.
  ///
  /// In en, this message translates to:
  /// **'Your access to this home has been revoked. The system will automatically switch to your default workspace.'**
  String get msg_kicked_desc;

  /// No description provided for @msg_disabled_desc.
  ///
  /// In en, this message translates to:
  /// **'Your account has been temporarily disabled'**
  String get msg_disabled_desc;

  /// No description provided for @msg_disabled_member.
  ///
  /// In en, this message translates to:
  /// **'Disabled {username}'**
  String msg_disabled_member(String username);

  /// No description provided for @msg_enabled_member.
  ///
  /// In en, this message translates to:
  /// **'Restored {username}'**
  String msg_enabled_member(String username);

  /// No description provided for @msg_role_granted.
  ///
  /// In en, this message translates to:
  /// **'Granted {role} to {username}'**
  String msg_role_granted(String role, String username);

  /// No description provided for @co_owner.
  ///
  /// In en, this message translates to:
  /// **'Co-owner'**
  String get co_owner;

  /// No description provided for @member_role.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member_role;

  /// No description provided for @username_member.
  ///
  /// In en, this message translates to:
  /// **'Username (Member)'**
  String get username_member;

  /// No description provided for @err_no_permission_scene.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to edit/delete this shared scene because you are not the creator.'**
  String get err_no_permission_scene;

  /// No description provided for @schedule_view_only.
  ///
  /// In en, this message translates to:
  /// **'Schedule Details (View Only)'**
  String get schedule_view_only;

  /// No description provided for @device_label.
  ///
  /// In en, this message translates to:
  /// **'Device:'**
  String get device_label;

  /// No description provided for @time_on_label.
  ///
  /// In en, this message translates to:
  /// **'Turn On Time:'**
  String get time_on_label;

  /// No description provided for @time_off_label.
  ///
  /// In en, this message translates to:
  /// **'Turn Off Time:'**
  String get time_off_label;

  /// No description provided for @err_no_permission_schedule.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to edit this shared schedule. Only the owner or an authorized person can edit.'**
  String get err_no_permission_schedule;

  /// No description provided for @btn_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get btn_close;

  /// No description provided for @update_phone_title.
  ///
  /// In en, this message translates to:
  /// **'Update Phone Number'**
  String get update_phone_title;

  /// No description provided for @update_email_title.
  ///
  /// In en, this message translates to:
  /// **'Update Email'**
  String get update_email_title;

  /// No description provided for @err_empty_phone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a phone number'**
  String get err_empty_phone;

  /// No description provided for @err_empty_email.
  ///
  /// In en, this message translates to:
  /// **'Please enter an email'**
  String get err_empty_email;

  /// No description provided for @reason_update_contact.
  ///
  /// In en, this message translates to:
  /// **'confirm changing contact information'**
  String get reason_update_contact;

  /// No description provided for @err_phone_already_linked.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already linked to another account'**
  String get err_phone_already_linked;

  /// No description provided for @err_check_data_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to check data, please try again'**
  String get err_check_data_failed;

  /// No description provided for @msg_verify_email_sent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent. Please check your inbox.'**
  String get msg_verify_email_sent;

  /// No description provided for @err_email_already_linked.
  ///
  /// In en, this message translates to:
  /// **'This email is already linked to another account'**
  String get err_email_already_linked;

  /// No description provided for @err_update_email.
  ///
  /// In en, this message translates to:
  /// **'Error updating email'**
  String get err_update_email;

  /// No description provided for @msg_update_phone_success.
  ///
  /// In en, this message translates to:
  /// **'Phone number updated successfully'**
  String get msg_update_phone_success;

  /// No description provided for @new_phone_number.
  ///
  /// In en, this message translates to:
  /// **'New Phone Number'**
  String get new_phone_number;

  /// No description provided for @new_email.
  ///
  /// In en, this message translates to:
  /// **'New Email'**
  String get new_email;

  /// No description provided for @enter_new_phone_desc.
  ///
  /// In en, this message translates to:
  /// **'Please enter your new phone number. An OTP will be sent for verification.'**
  String get enter_new_phone_desc;

  /// No description provided for @enter_new_email_desc.
  ///
  /// In en, this message translates to:
  /// **'Please enter your new email. A verification link will be sent to your inbox.'**
  String get enter_new_email_desc;

  /// No description provided for @email_address.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email_address;

  /// No description provided for @send_verify_email.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Email'**
  String get send_verify_email;

  /// No description provided for @err_require_trusted_device.
  ///
  /// In en, this message translates to:
  /// **'Only trusted devices can change linked accounts'**
  String get err_require_trusted_device;

  /// No description provided for @err_cannot_unlink_last.
  ///
  /// In en, this message translates to:
  /// **'Cannot unlink the only method (at least 1 Phone or Google link is required).'**
  String get err_cannot_unlink_last;

  /// No description provided for @msg_google_unlinked.
  ///
  /// In en, this message translates to:
  /// **'Google account unlinked successfully'**
  String get msg_google_unlinked;

  /// No description provided for @msg_google_linked.
  ///
  /// In en, this message translates to:
  /// **'Google account linked successfully'**
  String get msg_google_linked;

  /// No description provided for @msg_phone_unlinked.
  ///
  /// In en, this message translates to:
  /// **'Phone number unlinked successfully'**
  String get msg_phone_unlinked;

  /// No description provided for @status_linked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get status_linked;

  /// No description provided for @status_unlinked.
  ///
  /// In en, this message translates to:
  /// **'Unlinked'**
  String get status_unlinked;

  /// No description provided for @status_linked_safe.
  ///
  /// In en, this message translates to:
  /// **'Safely linked'**
  String get status_linked_safe;

  /// No description provided for @err_unlinked_account.
  ///
  /// In en, this message translates to:
  /// **'Account is not linked to any Phone/Email!'**
  String get err_unlinked_account;

  /// No description provided for @err_too_many_requests.
  ///
  /// In en, this message translates to:
  /// **'Account is temporarily locked due to too many failed attempts. Please try again later.'**
  String get err_too_many_requests;

  /// No description provided for @err_missing_google_id.
  ///
  /// In en, this message translates to:
  /// **'Missing GOOGLE_CLIENT_ID configuration'**
  String get err_missing_google_id;

  /// No description provided for @confirm_kick_device.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to kick device {device}?'**
  String confirm_kick_device(Object device);

  /// No description provided for @reason_kick_device.
  ///
  /// In en, this message translates to:
  /// **'confirm kicking device'**
  String get reason_kick_device;

  /// No description provided for @status_logged_in.
  ///
  /// In en, this message translates to:
  /// **'Logged in'**
  String get status_logged_in;

  /// No description provided for @status_logged_out.
  ///
  /// In en, this message translates to:
  /// **'Logged out'**
  String get status_logged_out;

  /// No description provided for @btn_request_trust.
  ///
  /// In en, this message translates to:
  /// **'Request Trust'**
  String get btn_request_trust;

  /// No description provided for @btn_request_sent.
  ///
  /// In en, this message translates to:
  /// **'Request Sent'**
  String get btn_request_sent;

  /// No description provided for @err_send_email.
  ///
  /// In en, this message translates to:
  /// **'Error sending email'**
  String get err_send_email;

  /// No description provided for @toast_mqtt_timeout.
  ///
  /// In en, this message translates to:
  /// **'Device unresponsive, action reverted!'**
  String get toast_mqtt_timeout;

  /// No description provided for @owner_role.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner_role;

  /// No description provided for @status_disabled.
  ///
  /// In en, this message translates to:
  /// **'Temporarily disabled'**
  String get status_disabled;

  /// No description provided for @status_normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get status_normal;

  /// No description provided for @err_no_phone_linked.
  ///
  /// In en, this message translates to:
  /// **'This account is not linked to a phone number for recovery.'**
  String get err_no_phone_linked;

  /// No description provided for @btn_create_account.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get btn_create_account;

  /// No description provided for @enter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get enter;

  /// No description provided for @last_login.
  ///
  /// In en, this message translates to:
  /// **'Last login:'**
  String get last_login;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @session_expired.
  ///
  /// In en, this message translates to:
  /// **'Session expired.'**
  String get session_expired;

  /// No description provided for @by_admin.
  ///
  /// In en, this message translates to:
  /// **'by home admin'**
  String get by_admin;

  /// No description provided for @err_switch_home_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to switch home:'**
  String get err_switch_home_failed;

  /// No description provided for @a_member.
  ///
  /// In en, this message translates to:
  /// **'A member'**
  String get a_member;

  /// No description provided for @act_add_timer.
  ///
  /// In en, this message translates to:
  /// **'added a new timer'**
  String get act_add_timer;

  /// No description provided for @act_cancel_timer.
  ///
  /// In en, this message translates to:
  /// **'canceled a timer'**
  String get act_cancel_timer;

  /// No description provided for @act_edit_scene.
  ///
  /// In en, this message translates to:
  /// **'edited a scene'**
  String get act_edit_scene;

  /// No description provided for @act_add_scene.
  ///
  /// In en, this message translates to:
  /// **'added a new scene'**
  String get act_add_scene;

  /// No description provided for @confirm_delete_scene.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this scene?'**
  String get confirm_delete_scene;

  /// No description provided for @act_delete_scene.
  ///
  /// In en, this message translates to:
  /// **'deleted a scene'**
  String get act_delete_scene;

  /// No description provided for @msg_scene_deleted.
  ///
  /// In en, this message translates to:
  /// **'Scene deleted successfully!'**
  String get msg_scene_deleted;

  /// No description provided for @err_select_device.
  ///
  /// In en, this message translates to:
  /// **'Please select a device'**
  String get err_select_device;

  /// No description provided for @act_edit_schedule.
  ///
  /// In en, this message translates to:
  /// **'edited a schedule'**
  String get act_edit_schedule;

  /// No description provided for @act_add_schedule.
  ///
  /// In en, this message translates to:
  /// **'added a new schedule'**
  String get act_add_schedule;

  /// No description provided for @act_delete_schedule.
  ///
  /// In en, this message translates to:
  /// **'deleted a schedule'**
  String get act_delete_schedule;

  /// No description provided for @err_esp32_already_linked.
  ///
  /// In en, this message translates to:
  /// **'The ESP32 device is already linked to this home. You cannot set it up again.'**
  String get err_esp32_already_linked;

  /// No description provided for @someone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get someone;

  /// No description provided for @msg_grant_edit.
  ///
  /// In en, this message translates to:
  /// **'Granted automation edit permission to'**
  String get msg_grant_edit;

  /// No description provided for @msg_revoke_edit.
  ///
  /// In en, this message translates to:
  /// **'Revoked automation edit permission from'**
  String get msg_revoke_edit;

  /// No description provided for @tooltip_permission.
  ///
  /// In en, this message translates to:
  /// **'Set Permission'**
  String get tooltip_permission;

  /// No description provided for @btn_kick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get btn_kick;

  /// No description provided for @err_empty_admin_pass.
  ///
  /// In en, this message translates to:
  /// **'Please enter Admin Password'**
  String get err_empty_admin_pass;

  /// No description provided for @step_check_esp_connection.
  ///
  /// In en, this message translates to:
  /// **'Checking connection to ESP32...'**
  String get step_check_esp_connection;

  /// No description provided for @step_esp_unreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to ESP32. Please connect to \'ZenHome_Setup_...\' WiFi.'**
  String get step_esp_unreachable;

  /// No description provided for @step_sending_config.
  ///
  /// In en, this message translates to:
  /// **'Sending configuration to device...'**
  String get step_sending_config;

  /// No description provided for @step_config_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send config. Please try again.'**
  String get step_config_failed;

  /// No description provided for @step_waiting_reboot.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device to reboot and connect (might take 1-2 minutes)...'**
  String get step_waiting_reboot;

  /// No description provided for @step_setup_failed.
  ///
  /// In en, this message translates to:
  /// **'Wrong WiFi password or MQTT failed. Please hold BOOT button for 5s to reset and try again.'**
  String get step_setup_failed;

  /// No description provided for @err_device_id_exists.
  ///
  /// In en, this message translates to:
  /// **'Device ID already exists!'**
  String get err_device_id_exists;

  /// No description provided for @esp32_hub.
  ///
  /// In en, this message translates to:
  /// **'Central Hub (ESP32)'**
  String get esp32_hub;

  /// No description provided for @reason_delete_account.
  ///
  /// In en, this message translates to:
  /// **'continue the account deletion process'**
  String get reason_delete_account;

  /// No description provided for @err_delete_account.
  ///
  /// In en, this message translates to:
  /// **'Error deleting account'**
  String get err_delete_account;

  /// No description provided for @msg_confirm_leave_home.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this home? You will lose all control.'**
  String get msg_confirm_leave_home;

  /// No description provided for @btn_leave_home.
  ///
  /// In en, this message translates to:
  /// **'Leave this home'**
  String get btn_leave_home;

  /// No description provided for @leave_home_title.
  ///
  /// In en, this message translates to:
  /// **'ACCESS MANAGEMENT'**
  String get leave_home_title;

  /// No description provided for @msg_leave_home_success.
  ///
  /// In en, this message translates to:
  /// **'Successfully left the virtual home.'**
  String get msg_leave_home_success;

  /// No description provided for @google_register_hint.
  ///
  /// In en, this message translates to:
  /// **'Google authenticated. Please set up a Password to secure your account.'**
  String get google_register_hint;

  /// No description provided for @unlinked.
  ///
  /// In en, this message translates to:
  /// **'Unlinked'**
  String get unlinked;

  /// No description provided for @verify_identity.
  ///
  /// In en, this message translates to:
  /// **'verify identity'**
  String get verify_identity;

  /// No description provided for @reauth_google_msg.
  ///
  /// In en, this message translates to:
  /// **'You need to sign in again with your Google account to continue.'**
  String get reauth_google_msg;

  /// No description provided for @err_hub_offline_delete.
  ///
  /// In en, this message translates to:
  /// **'The central hub is offline. Please turn on the Hub to clean up device memory before deleting your account.'**
  String get err_hub_offline_delete;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @err_email_not_registered.
  ///
  /// In en, this message translates to:
  /// **'This email is not registered!'**
  String get err_email_not_registered;

  /// No description provided for @err_credential_in_use.
  ///
  /// In en, this message translates to:
  /// **'This credential is already in use by another account.'**
  String get err_credential_in_use;

  /// No description provided for @shared_home.
  ///
  /// In en, this message translates to:
  /// **'Shared Home'**
  String get shared_home;

  /// No description provided for @send_sms.
  ///
  /// In en, this message translates to:
  /// **'Send OTP via SMS'**
  String get send_sms;

  /// No description provided for @err_no_recovery_method.
  ///
  /// In en, this message translates to:
  /// **'Your account has no recovery methods linked!'**
  String get err_no_recovery_method;

  /// No description provided for @choose_reset_method.
  ///
  /// In en, this message translates to:
  /// **'Please choose a recovery method:'**
  String get choose_reset_method;

  /// No description provided for @verify_via_google.
  ///
  /// In en, this message translates to:
  /// **'Verify via Google'**
  String get verify_via_google;

  /// No description provided for @account_found.
  ///
  /// In en, this message translates to:
  /// **'Account Found'**
  String get account_found;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm_unlink_google.
  ///
  /// In en, this message translates to:
  /// **'Unlink Google Account'**
  String get confirm_unlink_google;

  /// No description provided for @confirm_unlink_google_desc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unlink this Google account? (You can link it again later)'**
  String get confirm_unlink_google_desc;

  /// No description provided for @confirm_unlink_phone.
  ///
  /// In en, this message translates to:
  /// **'Unlink Phone Number'**
  String get confirm_unlink_phone;

  /// No description provided for @confirm_unlink_phone_desc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unlink this phone number? You will no longer be able to log in with it.'**
  String get confirm_unlink_phone_desc;

  /// No description provided for @confirm_change_phone.
  ///
  /// In en, this message translates to:
  /// **'Change Phone Number'**
  String get confirm_change_phone;

  /// No description provided for @confirm_change_phone_desc.
  ///
  /// In en, this message translates to:
  /// **'Changing your phone number will also change your login username. Are you sure you want to continue?'**
  String get confirm_change_phone_desc;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirm_exit.
  ///
  /// In en, this message translates to:
  /// **'Confirm Exit'**
  String get confirm_exit;

  /// No description provided for @msg_unsaved_changes.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to exit?'**
  String get msg_unsaved_changes;

  /// No description provided for @app_version_title.
  ///
  /// In en, this message translates to:
  /// **'VERSION & UPDATES'**
  String get app_version_title;

  /// No description provided for @check_for_updates.
  ///
  /// In en, this message translates to:
  /// **'Check for new updates'**
  String get check_for_updates;

  /// No description provided for @btn_check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get btn_check;

  /// No description provided for @checking_update.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checking_update;

  /// No description provided for @update_dialog_critical_badge.
  ///
  /// In en, this message translates to:
  /// **'CRITICAL UPDATE'**
  String get update_dialog_critical_badge;

  /// No description provided for @update_dialog_new_badge.
  ///
  /// In en, this message translates to:
  /// **'NEW VERSION AVAILABLE'**
  String get update_dialog_new_badge;

  /// No description provided for @current_version.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current_version;

  /// No description provided for @latest_version.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest_version;

  /// No description provided for @whats_new_in_release.
  ///
  /// In en, this message translates to:
  /// **'What\'s new in this release:'**
  String get whats_new_in_release;

  /// No description provided for @btn_later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get btn_later;

  /// No description provided for @btn_update_now.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get btn_update_now;

  /// No description provided for @err_cannot_check_update.
  ///
  /// In en, this message translates to:
  /// **'Unable to check for updates at this time. Please try again later.'**
  String get err_cannot_check_update;

  /// No description provided for @msg_app_up_to_date.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version!'**
  String get msg_app_up_to_date;

  /// No description provided for @downloading_update.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get downloading_update;

  /// No description provided for @preparing_download.
  ///
  /// In en, this message translates to:
  /// **'Preparing download...'**
  String get preparing_download;

  /// No description provided for @opening_installer.
  ///
  /// In en, this message translates to:
  /// **'Launching installer...'**
  String get opening_installer;

  /// No description provided for @download_error.
  ///
  /// In en, this message translates to:
  /// **'Could not download update from server'**
  String get download_error;

  /// No description provided for @new_version_available_title.
  ///
  /// In en, this message translates to:
  /// **'🚀 New ZenHome update available!'**
  String get new_version_available_title;

  /// No description provided for @new_version_available_body.
  ///
  /// In en, this message translates to:
  /// **'A new version is ready. Tap to update now!'**
  String get new_version_available_body;

  /// No description provided for @has_new_version_badge.
  ///
  /// In en, this message translates to:
  /// **'NEW UPDATE'**
  String get has_new_version_badge;

  /// No description provided for @btn_download_in_background.
  ///
  /// In en, this message translates to:
  /// **'Hide & Download in background'**
  String get btn_download_in_background;

  /// No description provided for @downloading_in_background_title.
  ///
  /// In en, this message translates to:
  /// **'Downloading ZenHome update'**
  String get downloading_in_background_title;

  /// No description provided for @download_complete_title.
  ///
  /// In en, this message translates to:
  /// **'Update download completed'**
  String get download_complete_title;

  /// No description provided for @download_complete_body.
  ///
  /// In en, this message translates to:
  /// **'Opening installer...'**
  String get download_complete_body;

  /// No description provided for @tab_scenes.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get tab_scenes;

  /// No description provided for @tab_automation.
  ///
  /// In en, this message translates to:
  /// **'Automations'**
  String get tab_automation;

  /// No description provided for @automation_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Device Timers & Automated Schedules'**
  String get automation_subtitle;

  /// No description provided for @device_not_linked_title.
  ///
  /// In en, this message translates to:
  /// **'Device Not Linked'**
  String get device_not_linked_title;

  /// No description provided for @device_not_linked_desc.
  ///
  /// In en, this message translates to:
  /// **'Utilities require pairing with a ZenHome Hub controller to run scenes and automations.'**
  String get device_not_linked_desc;

  /// No description provided for @device_offline_title.
  ///
  /// In en, this message translates to:
  /// **'System is Offline'**
  String get device_offline_title;

  /// No description provided for @device_offline_desc.
  ///
  /// In en, this message translates to:
  /// **'ZenHome Hub controller is unreachable. Waiting to reconnect to device...'**
  String get device_offline_desc;

  /// No description provided for @btn_setup_hub.
  ///
  /// In en, this message translates to:
  /// **'Set up Wi-Fi Hub'**
  String get btn_setup_hub;

  /// No description provided for @btn_reconnect.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get btn_reconnect;

  /// No description provided for @not_set.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get not_set;

  /// No description provided for @full_name.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get full_name;

  /// No description provided for @linked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get linked;

  /// No description provided for @unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @security_and_devices.
  ///
  /// In en, this message translates to:
  /// **'Security & Devices'**
  String get security_and_devices;

  /// No description provided for @danger_zone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get danger_zone;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @already_have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get already_have_account;

  /// No description provided for @access_restricted.
  ///
  /// In en, this message translates to:
  /// **'Access restricted'**
  String get access_restricted;

  /// No description provided for @manage_members.
  ///
  /// In en, this message translates to:
  /// **'Manage members'**
  String get manage_members;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @btn_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get btn_add;

  /// No description provided for @err_only_gmail_supported.
  ///
  /// In en, this message translates to:
  /// **'Only Google accounts ending in @gmail.com are supported!'**
  String get err_only_gmail_supported;

  /// No description provided for @reauth_google_select_account.
  ///
  /// In en, this message translates to:
  /// **'Please select the correct linked Google account ({email}) to verify!'**
  String reauth_google_select_account(String email);

  /// No description provided for @email_google.
  ///
  /// In en, this message translates to:
  /// **'Email (Google)'**
  String get email_google;

  /// No description provided for @update_phone_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Update Phone (OTP)'**
  String get update_phone_tooltip;

  /// No description provided for @report_bug_title.
  ///
  /// In en, this message translates to:
  /// **'Report Issue & Feedback'**
  String get report_bug_title;

  /// No description provided for @report_bug_desc.
  ///
  /// In en, this message translates to:
  /// **'Send feedback directly to the development team'**
  String get report_bug_desc;

  /// No description provided for @err_esp_required_for_invite.
  ///
  /// In en, this message translates to:
  /// **'You must link an ESP32 central hub to this home before inviting members.'**
  String get err_esp_required_for_invite;

  /// No description provided for @esp_required_for_invite_title.
  ///
  /// In en, this message translates to:
  /// **'ESP32 Hub Required'**
  String get esp_required_for_invite_title;

  /// No description provided for @esp_required_for_invite_desc.
  ///
  /// In en, this message translates to:
  /// **'Home sharing requires your home to be paired with a ZenHome Central Hub.'**
  String get esp_required_for_invite_desc;

  /// No description provided for @btn_link_hub_now.
  ///
  /// In en, this message translates to:
  /// **'Set up Wi-Fi Hub Now'**
  String get btn_link_hub_now;

  /// No description provided for @invite_member_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite family members to monitor and control smart home devices together'**
  String get invite_member_subtitle;

  /// No description provided for @role_co_owner_desc.
  ///
  /// In en, this message translates to:
  /// **'Full management & configuration rights'**
  String get role_co_owner_desc;

  /// No description provided for @role_member_desc.
  ///
  /// In en, this message translates to:
  /// **'Device control & status viewing'**
  String get role_member_desc;

  /// No description provided for @member_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get member_active;

  /// No description provided for @member_disabled.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get member_disabled;

  /// No description provided for @automation_edit_allowed.
  ///
  /// In en, this message translates to:
  /// **'Can edit automations'**
  String get automation_edit_allowed;

  /// No description provided for @automation_edit_denied.
  ///
  /// In en, this message translates to:
  /// **'View-only automations'**
  String get automation_edit_denied;

  /// No description provided for @admin_mapping_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure relay pins and map rooms for your devices'**
  String get admin_mapping_subtitle;

  /// No description provided for @sort_devices.
  ///
  /// In en, this message translates to:
  /// **'Sort Devices'**
  String get sort_devices;

  /// No description provided for @sorted_devices_success.
  ///
  /// In en, this message translates to:
  /// **'Devices sorted successfully'**
  String get sorted_devices_success;

  /// No description provided for @err_link_esp_first.
  ///
  /// In en, this message translates to:
  /// **'Please link an ESP32 hub before adding new devices!'**
  String get err_link_esp_first;

  /// No description provided for @device_empty_list.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get device_empty_list;

  /// No description provided for @device_empty_desc.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button below to add your first relay device for this home.'**
  String get device_empty_desc;

  /// No description provided for @btn_update_device.
  ///
  /// In en, this message translates to:
  /// **'Update Device'**
  String get btn_update_device;

  /// No description provided for @edit_device_title.
  ///
  /// In en, this message translates to:
  /// **'Edit Device'**
  String get edit_device_title;

  /// No description provided for @add_device_title.
  ///
  /// In en, this message translates to:
  /// **'Add Relay Device'**
  String get add_device_title;

  /// No description provided for @device_name_label.
  ///
  /// In en, this message translates to:
  /// **'Device Name (e.g. Ceiling Light)'**
  String get device_name_label;

  /// No description provided for @device_id_label.
  ///
  /// In en, this message translates to:
  /// **'Identifier (Device ID)'**
  String get device_id_label;

  /// No description provided for @select_pin_label.
  ///
  /// In en, this message translates to:
  /// **'Relay GPIO Pin (PIN)'**
  String get select_pin_label;

  /// No description provided for @unsaved_changes_device_title.
  ///
  /// In en, this message translates to:
  /// **'Save device changes?'**
  String get unsaved_changes_device_title;

  /// No description provided for @unsaved_changes_device_desc.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved device changes. Do you want to save them before leaving?'**
  String get unsaved_changes_device_desc;

  /// No description provided for @confirm_delete_device_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Device'**
  String get confirm_delete_device_title;

  /// No description provided for @confirm_delete_device_desc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this device from this home?'**
  String get confirm_delete_device_desc;

  /// No description provided for @mark_all_read.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get mark_all_read;

  /// No description provided for @notification_category_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notification_category_all;

  /// No description provided for @notification_category_update.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get notification_category_update;

  /// No description provided for @notification_category_important.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get notification_category_important;

  /// No description provided for @notification_category_schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get notification_category_schedule;

  /// No description provided for @notification_category_timer.
  ///
  /// In en, this message translates to:
  /// **'Timers'**
  String get notification_category_timer;

  /// No description provided for @notification_category_action.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get notification_category_action;

  /// No description provided for @notification_category_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get notification_category_other;

  /// No description provided for @empty_notification_desc.
  ///
  /// In en, this message translates to:
  /// **'Your notification inbox is clean. New events will appear here.'**
  String get empty_notification_desc;

  /// No description provided for @shared_home_badge.
  ///
  /// In en, this message translates to:
  /// **'Shared Home'**
  String get shared_home_badge;

  /// No description provided for @no_internet_title.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get no_internet_title;

  /// No description provided for @no_internet_desc.
  ///
  /// In en, this message translates to:
  /// **'Please check your Wi-Fi or cellular (4G/5G) network to continue using ZenHome.'**
  String get no_internet_desc;

  /// No description provided for @no_internet_banner.
  ///
  /// In en, this message translates to:
  /// **'No Internet connection. Operating in Offline Mode.'**
  String get no_internet_banner;

  /// No description provided for @internet_restored_banner.
  ///
  /// In en, this message translates to:
  /// **'Internet connection restored.'**
  String get internet_restored_banner;

  /// No description provided for @btn_continue_offline.
  ///
  /// In en, this message translates to:
  /// **'Continue Offline'**
  String get btn_continue_offline;

  /// No description provided for @wifi_prep_title.
  ///
  /// In en, this message translates to:
  /// **'Device Preparation'**
  String get wifi_prep_title;

  /// No description provided for @wifi_prep_desc.
  ///
  /// In en, this message translates to:
  /// **'Prepare the ZenHome Hub (ESP32) controller before installation.'**
  String get wifi_prep_desc;

  /// No description provided for @wifi_step1_title.
  ///
  /// In en, this message translates to:
  /// **'Power on the device'**
  String get wifi_step1_title;

  /// No description provided for @wifi_step1_desc.
  ///
  /// In en, this message translates to:
  /// **'Use a Type-C charger or a stable 5V power supply to power the ZenHome Hub.'**
  String get wifi_step1_desc;

  /// No description provided for @wifi_step2_title.
  ///
  /// In en, this message translates to:
  /// **'Check status LED'**
  String get wifi_step2_title;

  /// No description provided for @wifi_step2_desc.
  ///
  /// In en, this message translates to:
  /// **'The blue LED on the board flashes steadily indicating the device is broadcasting setup Wi-Fi AP.'**
  String get wifi_step2_desc;

  /// No description provided for @wifi_step3_title.
  ///
  /// In en, this message translates to:
  /// **'Connect phone to device Wi-Fi'**
  String get wifi_step3_title;

  /// No description provided for @wifi_step3_desc.
  ///
  /// In en, this message translates to:
  /// **'Open Wi-Fi Settings on your phone and select the network starting with \'ZenHome_Setup_...\' (No password required).'**
  String get wifi_step3_desc;

  /// No description provided for @wifi_step_prep.
  ///
  /// In en, this message translates to:
  /// **'Preparation'**
  String get wifi_step_prep;

  /// No description provided for @wifi_step_config.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get wifi_step_config;

  /// No description provided for @wifi_step_pair.
  ///
  /// In en, this message translates to:
  /// **'Pairing'**
  String get wifi_step_pair;

  /// No description provided for @wifi_step_done.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get wifi_step_done;

  /// No description provided for @wifi_checking_esp.
  ///
  /// In en, this message translates to:
  /// **'Scanning for device...'**
  String get wifi_checking_esp;

  /// No description provided for @wifi_check_esp_btn.
  ///
  /// In en, this message translates to:
  /// **'Check ESP32 connection'**
  String get wifi_check_esp_btn;

  /// No description provided for @wifi_found_esp.
  ///
  /// In en, this message translates to:
  /// **'Device found!'**
  String get wifi_found_esp;

  /// No description provided for @wifi_check_conn_label.
  ///
  /// In en, this message translates to:
  /// **'Check connection:'**
  String get wifi_check_conn_label;

  /// No description provided for @wifi_btn_continue_config.
  ///
  /// In en, this message translates to:
  /// **'Continue: Wi-Fi Setup'**
  String get wifi_btn_continue_config;

  /// No description provided for @wifi_home_info_section.
  ///
  /// In en, this message translates to:
  /// **'Your Home Wi-Fi (2.4GHz)'**
  String get wifi_home_info_section;

  /// No description provided for @wifi_admin_pass_section.
  ///
  /// In en, this message translates to:
  /// **'Device Technical Password'**
  String get wifi_admin_pass_section;

  /// No description provided for @wifi_admin_pass_label.
  ///
  /// In en, this message translates to:
  /// **'Technical Password'**
  String get wifi_admin_pass_label;

  /// No description provided for @wifi_admin_pass_hint.
  ///
  /// In en, this message translates to:
  /// **'Board admin password'**
  String get wifi_admin_pass_hint;

  /// No description provided for @wifi_confirm_admin_pass_label.
  ///
  /// In en, this message translates to:
  /// **'Confirm Technical Password'**
  String get wifi_confirm_admin_pass_label;

  /// No description provided for @wifi_confirm_admin_pass_hint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter technical password'**
  String get wifi_confirm_admin_pass_hint;

  /// No description provided for @wifi_mqtt_adv_title.
  ///
  /// In en, this message translates to:
  /// **'MQTT Server Settings (Advanced)'**
  String get wifi_mqtt_adv_title;

  /// No description provided for @wifi_mqtt_default_cloud.
  ///
  /// In en, this message translates to:
  /// **'Default EMQX Cloud'**
  String get wifi_mqtt_default_cloud;

  /// No description provided for @wifi_btn_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get wifi_btn_back;

  /// No description provided for @wifi_btn_start_pairing.
  ///
  /// In en, this message translates to:
  /// **'Start Pairing'**
  String get wifi_btn_start_pairing;

  /// No description provided for @wifi_pairing_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Pairing Failed'**
  String get wifi_pairing_failed_title;

  /// No description provided for @wifi_btn_change_wifi_pass.
  ///
  /// In en, this message translates to:
  /// **'Change Wi-Fi Password'**
  String get wifi_btn_change_wifi_pass;

  /// No description provided for @wifi_btn_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get wifi_btn_retry;

  /// No description provided for @wifi_pairing_success_title.
  ///
  /// In en, this message translates to:
  /// **'Device Paired Successfully!'**
  String get wifi_pairing_success_title;

  /// No description provided for @wifi_pairing_success_desc.
  ///
  /// In en, this message translates to:
  /// **'The ZenHome Hub device has connected to Wi-Fi and is online on the server.'**
  String get wifi_pairing_success_desc;

  /// No description provided for @wifi_btn_device_mapping.
  ///
  /// In en, this message translates to:
  /// **'Device Mapping'**
  String get wifi_btn_device_mapping;

  /// No description provided for @wifi_btn_return_home.
  ///
  /// In en, this message translates to:
  /// **'Return to Home'**
  String get wifi_btn_return_home;

  /// No description provided for @wifi_esp_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected to ESP32 ({mac})'**
  String wifi_esp_connected(Object mac);

  /// No description provided for @wifi_esp_not_found.
  ///
  /// In en, this message translates to:
  /// **'Device not found. Make sure phone is connected to \'ZenHome_Setup_...\' Wi-Fi'**
  String get wifi_esp_not_found;

  /// No description provided for @wifi_waiting_mqtt.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device to connect to Wi-Fi and become online on MQTT server...'**
  String get wifi_waiting_mqtt;

  /// No description provided for @wifi_pair_error_hint.
  ///
  /// In en, this message translates to:
  /// **'Wrong Wi-Fi password or device cannot connect to server. Please hold the BOOT button for 5s to reset and retry.'**
  String get wifi_pair_error_hint;

  /// No description provided for @bug_report_category_ui.
  ///
  /// In en, this message translates to:
  /// **'User Interface'**
  String get bug_report_category_ui;

  /// No description provided for @bug_report_category_network.
  ///
  /// In en, this message translates to:
  /// **'Network Connection'**
  String get bug_report_category_network;

  /// No description provided for @bug_report_category_control.
  ///
  /// In en, this message translates to:
  /// **'Device Control'**
  String get bug_report_category_control;

  /// No description provided for @bug_report_category_scene.
  ///
  /// In en, this message translates to:
  /// **'Scenes & Automation'**
  String get bug_report_category_scene;

  /// No description provided for @bug_report_category_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get bug_report_category_other;

  /// No description provided for @bug_report_err_empty_title.
  ///
  /// In en, this message translates to:
  /// **'Please enter a bug title summary!'**
  String get bug_report_err_empty_title;

  /// No description provided for @bug_report_err_empty_desc.
  ///
  /// In en, this message translates to:
  /// **'Please describe the issue in detail!'**
  String get bug_report_err_empty_desc;

  /// No description provided for @bug_report_device_mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get bug_report_device_mobile;

  /// No description provided for @bug_report_user_zenhome.
  ///
  /// In en, this message translates to:
  /// **'ZenHome User'**
  String get bug_report_user_zenhome;

  /// No description provided for @bug_report_success_msg.
  ///
  /// In en, this message translates to:
  /// **'Bug report submitted successfully! The admin team will review your feedback.'**
  String get bug_report_success_msg;

  /// No description provided for @bug_report_send_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report:'**
  String get bug_report_send_failed;

  /// No description provided for @bug_report_modal_title.
  ///
  /// In en, this message translates to:
  /// **'Bug Report & Feedback'**
  String get bug_report_modal_title;

  /// No description provided for @bug_report_modal_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback will be sent directly to the administrators'**
  String get bug_report_modal_subtitle;

  /// No description provided for @bug_report_category_label.
  ///
  /// In en, this message translates to:
  /// **'Issue Category'**
  String get bug_report_category_label;

  /// No description provided for @bug_report_title_label.
  ///
  /// In en, this message translates to:
  /// **'Summary Title'**
  String get bug_report_title_label;

  /// No description provided for @bug_report_title_hint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Fan button does not respond...'**
  String get bug_report_title_hint;

  /// No description provided for @bug_report_desc_label.
  ///
  /// In en, this message translates to:
  /// **'Detailed Description'**
  String get bug_report_desc_label;

  /// No description provided for @bug_report_desc_hint.
  ///
  /// In en, this message translates to:
  /// **'Describe specific steps to reproduce or when the issue happened...'**
  String get bug_report_desc_hint;

  /// No description provided for @bug_report_auto_attach_hint.
  ///
  /// In en, this message translates to:
  /// **'Device info & app version will be automatically attached for best support.'**
  String get bug_report_auto_attach_hint;

  /// No description provided for @bug_report_btn_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit Bug Report'**
  String get bug_report_btn_submit;

  /// No description provided for @tooltip_change_phone.
  ///
  /// In en, this message translates to:
  /// **'Change phone number'**
  String get tooltip_change_phone;

  /// No description provided for @err_create_pass_before_unlink_google.
  ///
  /// In en, this message translates to:
  /// **'You must create a password (in Change Password) before unlinking Google to be able to sign in.'**
  String get err_create_pass_before_unlink_google;

  /// No description provided for @err_create_pass_before_unlink_phone.
  ///
  /// In en, this message translates to:
  /// **'You must create a password (in Change Password) before unlinking phone to ensure you can still sign in.'**
  String get err_create_pass_before_unlink_phone;

  /// No description provided for @btn_leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get btn_leave;

  /// No description provided for @btn_stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get btn_stay;

  /// No description provided for @register_sms_otp_hint.
  ///
  /// In en, this message translates to:
  /// **'A verification OTP will be sent via SMS to activate your account.'**
  String get register_sms_otp_hint;

  /// No description provided for @register_btn_get_otp.
  ///
  /// In en, this message translates to:
  /// **'Continue to receive OTP'**
  String get register_btn_get_otp;

  /// No description provided for @register_verified_phone.
  ///
  /// In en, this message translates to:
  /// **'Verified: {phone}'**
  String register_verified_phone(Object phone);

  /// No description provided for @err_reauth_select_google.
  ///
  /// In en, this message translates to:
  /// **'Please select the matching linked Google account ({email}) to authenticate!'**
  String err_reauth_select_google(Object email);

  /// No description provided for @err_google_auth_failed.
  ///
  /// In en, this message translates to:
  /// **'Google authentication error: {err}'**
  String err_google_auth_failed(Object err);

  /// No description provided for @role_co_owner_full.
  ///
  /// In en, this message translates to:
  /// **'Co-Owner'**
  String get role_co_owner_full;

  /// No description provided for @device_count_label.
  ///
  /// In en, this message translates to:
  /// **'{count} devices'**
  String device_count_label(Object count);

  /// No description provided for @relay_device_title.
  ///
  /// In en, this message translates to:
  /// **'Relay / Devices'**
  String get relay_device_title;

  /// No description provided for @switching_to_home.
  ///
  /// In en, this message translates to:
  /// **'Switching to {name}...'**
  String switching_to_home(Object name);

  /// No description provided for @switched_to_home.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String switched_to_home(Object name);

  /// No description provided for @update_confirm_cancel_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm Cancellation'**
  String get update_confirm_cancel_title;

  /// No description provided for @update_confirm_cancel_desc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel downloading this update? Download progress will be stopped.'**
  String get update_confirm_cancel_desc;

  /// No description provided for @update_keep_downloading.
  ///
  /// In en, this message translates to:
  /// **'Keep Downloading'**
  String get update_keep_downloading;

  /// No description provided for @update_btn_cancel_download.
  ///
  /// In en, this message translates to:
  /// **'Cancel Download'**
  String get update_btn_cancel_download;

  /// No description provided for @update_download_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Update Download Failed'**
  String get update_download_failed_title;

  /// No description provided for @update_troubleshoot_title.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting Checklist'**
  String get update_troubleshoot_title;

  /// No description provided for @update_troubleshoot_step1.
  ///
  /// In en, this message translates to:
  /// **'• Ensure phone and ZenHome server computer are on the same Wi-Fi network.'**
  String get update_troubleshoot_step1;

  /// No description provided for @update_troubleshoot_step2.
  ///
  /// In en, this message translates to:
  /// **'• Check if ZenHome Server (IP: {ip}) is active.'**
  String update_troubleshoot_step2(Object ip);

  /// No description provided for @update_troubleshoot_step3.
  ///
  /// In en, this message translates to:
  /// **'• If direct in-app download fails, you can download the APK file directly via Browser.'**
  String get update_troubleshoot_step3;

  /// No description provided for @update_btn_browser.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get update_btn_browser;

  /// No description provided for @update_cannot_open_link.
  ///
  /// In en, this message translates to:
  /// **'Could not open update link: {url}'**
  String update_cannot_open_link(Object url);

  /// No description provided for @update_direct_failed.
  ///
  /// In en, this message translates to:
  /// **'Direct in-app download failed'**
  String get update_direct_failed;

  /// No description provided for @update_time_remaining_s.
  ///
  /// In en, this message translates to:
  /// **'~{sec}s remaining'**
  String update_time_remaining_s(Object sec);

  /// No description provided for @update_time_remaining_ms.
  ///
  /// In en, this message translates to:
  /// **'~{min}m {sec}s remaining'**
  String update_time_remaining_ms(Object min, Object sec);

  /// No description provided for @update_speed_connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get update_speed_connecting;

  /// No description provided for @wifi_scan_esp_btn.
  ///
  /// In en, this message translates to:
  /// **'Scan ESP32 Signal'**
  String get wifi_scan_esp_btn;

  /// No description provided for @wifi_scanning_signal.
  ///
  /// In en, this message translates to:
  /// **'Scanning for nearby ESP32 signals...'**
  String get wifi_scanning_signal;

  /// No description provided for @wifi_detected_esp_title.
  ///
  /// In en, this message translates to:
  /// **'Detected ESP32 Signals ({count})'**
  String wifi_detected_esp_title(Object count);

  /// No description provided for @wifi_no_esp_found.
  ///
  /// In en, this message translates to:
  /// **'No ESP32 signal detected nearby. Please ensure the board is powered on and LED is blinking in setup mode.'**
  String get wifi_no_esp_found;

  /// No description provided for @wifi_connect_esp_title.
  ///
  /// In en, this message translates to:
  /// **'Connect to {ssid}'**
  String wifi_connect_esp_title(Object ssid);

  /// No description provided for @wifi_connect_esp_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the ESP32 AP password (leave empty if open network without password):'**
  String get wifi_connect_esp_subtitle;

  /// No description provided for @wifi_esp_pass_label.
  ///
  /// In en, this message translates to:
  /// **'ESP32 Wi-Fi Password'**
  String get wifi_esp_pass_label;

  /// No description provided for @wifi_esp_pass_hint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if open, or enter AP password'**
  String get wifi_esp_pass_hint;

  /// No description provided for @wifi_btn_connect_now.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Connect'**
  String get wifi_btn_connect_now;

  /// No description provided for @wifi_connecting_in_app.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {ssid}...'**
  String wifi_connecting_in_app(Object ssid);

  /// No description provided for @wifi_connect_success.
  ///
  /// In en, this message translates to:
  /// **'Successfully connected to {ssid}!'**
  String wifi_connect_success(Object ssid);

  /// No description provided for @wifi_connect_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to {ssid}. Please retry or open Phone Settings.'**
  String wifi_connect_failed(Object ssid);

  /// No description provided for @wifi_open_settings_shortcut.
  ///
  /// In en, this message translates to:
  /// **'Open Phone Wi-Fi Settings'**
  String get wifi_open_settings_shortcut;

  /// No description provided for @wifi_signal_quality.
  ///
  /// In en, this message translates to:
  /// **'Signal: {rssi} dBm ({quality})'**
  String wifi_signal_quality(Object quality, Object rssi);

  /// No description provided for @wifi_signal_strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get wifi_signal_strong;

  /// No description provided for @wifi_signal_medium.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get wifi_signal_medium;

  /// No description provided for @wifi_signal_weak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get wifi_signal_weak;

  /// No description provided for @wifi_scan_nearby_home_btn.
  ///
  /// In en, this message translates to:
  /// **'Pick from Nearby Wi-Fi'**
  String get wifi_scan_nearby_home_btn;

  /// No description provided for @wifi_select_home_wifi_title.
  ///
  /// In en, this message translates to:
  /// **'Select Home Wi-Fi (2.4GHz)'**
  String get wifi_select_home_wifi_title;

  /// No description provided for @wifi_scanning_home.
  ///
  /// In en, this message translates to:
  /// **'Scanning for home Wi-Fi networks...'**
  String get wifi_scanning_home;

  /// No description provided for @wifi_current_status_title.
  ///
  /// In en, this message translates to:
  /// **'Current Wi-Fi Status'**
  String get wifi_current_status_title;

  /// No description provided for @wifi_current_connected_to.
  ///
  /// In en, this message translates to:
  /// **'Connected to: {ssid}'**
  String wifi_current_connected_to(Object ssid);

  /// No description provided for @wifi_current_disconnected.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Disconnected'**
  String get wifi_current_disconnected;

  /// No description provided for @wifi_current_esp_connected.
  ///
  /// In en, this message translates to:
  /// **'ESP32 SIGNAL CAPTURED'**
  String get wifi_current_esp_connected;

  /// No description provided for @wifi_current_esp_desc.
  ///
  /// In en, this message translates to:
  /// **'Phone is connected to device Wi-Fi. Tap Handshake Now to verify response.'**
  String get wifi_current_esp_desc;

  /// No description provided for @wifi_gps_disabled_warning.
  ///
  /// In en, this message translates to:
  /// **'Location (GPS) is turned off. Android requires Location to scan Wi-Fi signals.'**
  String get wifi_gps_disabled_warning;

  /// No description provided for @wifi_btn_turn_on_gps.
  ///
  /// In en, this message translates to:
  /// **'Turn On Location (GPS)'**
  String get wifi_btn_turn_on_gps;

  /// No description provided for @wifi_adapter_disabled_warning.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi is currently disabled. Please enable Wi-Fi to find ESP32.'**
  String get wifi_adapter_disabled_warning;

  /// No description provided for @wifi_btn_turn_on_wifi.
  ///
  /// In en, this message translates to:
  /// **'Turn On Wi-Fi'**
  String get wifi_btn_turn_on_wifi;

  /// No description provided for @wifi_progress_modal_title.
  ///
  /// In en, this message translates to:
  /// **'ESP32 Connection Progress'**
  String get wifi_progress_modal_title;

  /// No description provided for @wifi_progress_step1_req.
  ///
  /// In en, this message translates to:
  /// **'Requesting Wi-Fi connection ({ssid})...'**
  String wifi_progress_step1_req(Object ssid);

  /// No description provided for @wifi_progress_step2_route.
  ///
  /// In en, this message translates to:
  /// **'Configuring local IoT Wi-Fi priority...'**
  String get wifi_progress_step2_route;

  /// No description provided for @wifi_progress_step3_handshake.
  ///
  /// In en, this message translates to:
  /// **'Handshaking with ESP32 ({retry}/6)...'**
  String wifi_progress_step3_handshake(Object retry);

  /// No description provided for @wifi_progress_step4_success.
  ///
  /// In en, this message translates to:
  /// **'Signal Captured & Connected!'**
  String get wifi_progress_step4_success;

  /// No description provided for @wifi_progress_step4_desc.
  ///
  /// In en, this message translates to:
  /// **'ESP32 verified (MAC: {mac}). Moving to configuration...'**
  String wifi_progress_step4_desc(Object mac);

  /// No description provided for @wifi_progress_step4_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to capture signal or connect to ESP32'**
  String get wifi_progress_step4_failed;

  /// No description provided for @wifi_progress_failed_reason.
  ///
  /// In en, this message translates to:
  /// **'Possible causes: Device out of range, wrong password, or phone rejected network without Internet.'**
  String get wifi_progress_failed_reason;

  /// No description provided for @wifi_btn_retry_connect.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get wifi_btn_retry_connect;

  /// No description provided for @wifi_handshake_now_btn.
  ///
  /// In en, this message translates to:
  /// **'Handshake & Verify Now'**
  String get wifi_handshake_now_btn;

  /// No description provided for @wifi_handshake_success.
  ///
  /// In en, this message translates to:
  /// **'Handshake successful with ESP32 (MAC: {mac})!'**
  String wifi_handshake_success(Object mac);

  /// No description provided for @wifi_handshake_failed.
  ///
  /// In en, this message translates to:
  /// **'ESP32 did not respond at 192.168.4.1. Please retry!'**
  String get wifi_handshake_failed;

  /// No description provided for @restart_hub_title.
  ///
  /// In en, this message translates to:
  /// **'Restart ESP32 Hub'**
  String get restart_hub_title;

  /// No description provided for @restart_hub_desc.
  ///
  /// In en, this message translates to:
  /// **'Send remote reboot signal to MCU'**
  String get restart_hub_desc;

  /// No description provided for @restart_hub_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Restart Central Hub ESP32?'**
  String get restart_hub_confirm_title;

  /// No description provided for @restart_hub_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'The system will send a remote reboot signal to ESP32. Connections and devices may be temporarily interrupted for 5-10 seconds.'**
  String get restart_hub_confirm_desc;

  /// No description provided for @restart_hub_offline_err.
  ///
  /// In en, this message translates to:
  /// **'ESP32 Hub is currently offline. Cannot receive remote reboot command.'**
  String get restart_hub_offline_err;

  /// No description provided for @restart_hub_success_title.
  ///
  /// In en, this message translates to:
  /// **'Reboot Command Sent'**
  String get restart_hub_success_title;

  /// No description provided for @restart_hub_success_desc.
  ///
  /// In en, this message translates to:
  /// **'ESP32 Hub received command and is restarting. The system will automatically reconnect when ready.'**
  String get restart_hub_success_desc;

  /// No description provided for @unlink_hub_menu_title.
  ///
  /// In en, this message translates to:
  /// **'Unlink Hub'**
  String get unlink_hub_menu_title;

  /// No description provided for @unlink_hub_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm Wipe & Unlink Hub?'**
  String get unlink_hub_confirm_title;

  /// No description provided for @unlink_hub_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'This command will send a signal to wipe configuration (/config.json) on ESP32, turn off all relays, and reboot ESP32 into AP setup mode.'**
  String get unlink_hub_confirm_desc;

  /// No description provided for @unlink_hub_offline_warning.
  ///
  /// In en, this message translates to:
  /// **'ESP32 Hub is offline. For security and remote chip data wipe (Factory Reset), the Hub must be Online.'**
  String get unlink_hub_offline_warning;

  /// No description provided for @unlink_hub_success_title.
  ///
  /// In en, this message translates to:
  /// **'Hub Unlinked Successfully'**
  String get unlink_hub_success_title;

  /// No description provided for @unlink_hub_success_desc.
  ///
  /// In en, this message translates to:
  /// **'Remote Reset command sent to ESP32. Device wiped configuration and is rebooting into AP Setup mode.'**
  String get unlink_hub_success_desc;

  /// No description provided for @err_duplicate_gpio.
  ///
  /// In en, this message translates to:
  /// **'GPIO pin {pin} is already assigned to device \'{name}\'. Please choose another pin!'**
  String err_duplicate_gpio(Object name, Object pin);

  /// No description provided for @err_duplicate_name_room.
  ///
  /// In en, this message translates to:
  /// **'Device name \'{name}\' already exists in {room}. Please choose a different name!'**
  String err_duplicate_name_room(Object name, Object room);

  /// No description provided for @mapping_saved_title.
  ///
  /// In en, this message translates to:
  /// **'Device Mapping Saved'**
  String get mapping_saved_title;

  /// No description provided for @mapping_saved_desc.
  ///
  /// In en, this message translates to:
  /// **'All device, room, and GPIO mappings have been synced to Cloud and reloaded to ESP32 Hub.'**
  String get mapping_saved_desc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
