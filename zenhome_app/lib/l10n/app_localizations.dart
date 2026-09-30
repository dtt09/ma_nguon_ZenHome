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
  /// **'Add Device'**
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
  /// **'Not linked'**
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
