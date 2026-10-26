/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `activity_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned DEFAULT NULL,
  `action` varchar(60) NOT NULL,
  `entity_type` varchar(40) DEFAULT NULL,
  `entity_id` int(10) unsigned DEFAULT NULL,
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`metadata`)),
  `client_event_id` varchar(36) DEFAULT NULL,
  `occurred_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `activity_logs_user_id_client_event_id_unique` (`user_id`,`client_event_id`),
  KEY `activity_logs_user_id_occurred_at_index` (`user_id`,`occurred_at`),
  KEY `activity_logs_action_occurred_at_index` (`action`,`occurred_at`),
  KEY `activity_logs_entity_type_entity_id_index` (`entity_type`,`entity_id`),
  CONSTRAINT `activity_logs_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ad_attachments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ad_id` int(10) unsigned NOT NULL,
  `kind` enum('file','link') NOT NULL,
  `title` varchar(255) DEFAULT NULL,
  `path` varchar(255) DEFAULT NULL,
  `url` varchar(1000) DEFAULT NULL,
  `mime` varchar(100) DEFAULT NULL,
  `size` int(10) unsigned DEFAULT NULL,
  `display_order` int(11) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `ad_attachments_ad_id_display_order_index` (`ad_id`,`display_order`),
  CONSTRAINT `ad_attachments_ad_id_foreign` FOREIGN KEY (`ad_id`) REFERENCES `advertisements` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `advertisements` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `kind` enum('advertisement','event','announcement','campaign','info') NOT NULL DEFAULT 'advertisement',
  `title` varchar(255) NOT NULL,
  `short_description` varchar(500) DEFAULT NULL,
  `image` varchar(255) DEFAULT NULL,
  `starts_at` datetime DEFAULT NULL,
  `ends_at` datetime DEFAULT NULL,
  `display_order` int(11) NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `page_id` int(10) unsigned DEFAULT NULL,
  `program_id` int(10) unsigned DEFAULT NULL,
  `created_by` int(10) unsigned DEFAULT NULL,
  `updated_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `advertisements_page_id_foreign` (`page_id`),
  KEY `advertisements_program_id_foreign` (`program_id`),
  KEY `advertisements_created_by_foreign` (`created_by`),
  KEY `advertisements_updated_by_foreign` (`updated_by`),
  KEY `advertisements_is_active_starts_at_ends_at_index` (`is_active`,`starts_at`,`ends_at`),
  KEY `advertisements_display_order_index` (`display_order`),
  CONSTRAINT `advertisements_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `advertisements_page_id_foreign` FOREIGN KEY (`page_id`) REFERENCES `pages` (`id`) ON DELETE SET NULL,
  CONSTRAINT `advertisements_program_id_foreign` FOREIGN KEY (`program_id`) REFERENCES `programs` (`id`) ON DELETE SET NULL,
  CONSTRAINT `advertisements_updated_by_foreign` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `app_releases` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `platform` enum('android') NOT NULL DEFAULT 'android',
  `version_name` varchar(32) NOT NULL,
  `version_code` int(10) unsigned NOT NULL,
  `file_path` varchar(255) NOT NULL,
  `file_size` bigint(20) unsigned NOT NULL,
  `sha256` varchar(64) NOT NULL,
  `release_notes` text DEFAULT NULL,
  `min_supported_code` int(10) unsigned NOT NULL DEFAULT 0,
  `is_mandatory` tinyint(1) NOT NULL DEFAULT 0,
  `is_published` tinyint(1) NOT NULL DEFAULT 1,
  `download_count` int(10) unsigned NOT NULL DEFAULT 0,
  `created_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `app_releases_platform_version_code_unique` (`platform`,`version_code`),
  KEY `app_releases_created_by_foreign` (`created_by`),
  CONSTRAINT `app_releases_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `attendance` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `program_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `status` enum('present','late','absent','excused') NOT NULL DEFAULT 'present',
  `attended_at` datetime DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `recorded_by` int(10) unsigned DEFAULT NULL,
  `updated_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `occurrence_date` date NOT NULL,
  `via` enum('qr','manual') DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `attendance_occurrence_unique` (`program_id`,`occurrence_date`,`user_id`),
  KEY `attendance_recorded_by_foreign` (`recorded_by`),
  KEY `attendance_updated_by_foreign` (`updated_by`),
  KEY `attendance_user_id_attended_at_index` (`user_id`,`attended_at`),
  KEY `attendance_user_id_occurrence_date_index` (`user_id`,`occurrence_date`),
  CONSTRAINT `attendance_program_id_foreign` FOREIGN KEY (`program_id`) REFERENCES `programs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `attendance_recorded_by_foreign` FOREIGN KEY (`recorded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `attendance_updated_by_foreign` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `attendance_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `attendance_closures` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `program_id` int(10) unsigned NOT NULL,
  `occurrence_date` date NOT NULL,
  `closed_by` int(10) unsigned DEFAULT NULL,
  `closed_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `attendance_closures_program_id_occurrence_date_unique` (`program_id`,`occurrence_date`),
  KEY `attendance_closures_closed_by_foreign` (`closed_by`),
  CONSTRAINT `attendance_closures_closed_by_foreign` FOREIGN KEY (`closed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `attendance_closures_program_id_foreign` FOREIGN KEY (`program_id`) REFERENCES `programs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `attendance_corrections` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `program_id` int(10) unsigned NOT NULL,
  `occurrence_date` date NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `original_status` varchar(20) NOT NULL,
  `requested_status` enum('present','late','excused','absent') DEFAULT NULL,
  `reason` varchar(1000) NOT NULL,
  `status` enum('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `requested_by` int(10) unsigned DEFAULT NULL,
  `reviewed_by` int(10) unsigned DEFAULT NULL,
  `review_note` varchar(1000) DEFAULT NULL,
  `final_status` varchar(20) DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `attendance_corrections_user_id_foreign` (`user_id`),
  KEY `attendance_corrections_requested_by_foreign` (`requested_by`),
  KEY `attendance_corrections_reviewed_by_foreign` (`reviewed_by`),
  KEY `attendance_corrections_status_created_at_index` (`status`,`created_at`),
  KEY `attendance_corrections_program_id_occurrence_date_index` (`program_id`,`occurrence_date`),
  CONSTRAINT `attendance_corrections_program_id_foreign` FOREIGN KEY (`program_id`) REFERENCES `programs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `attendance_corrections_requested_by_foreign` FOREIGN KEY (`requested_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `attendance_corrections_reviewed_by_foreign` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `attendance_corrections_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `audit_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `actor_id` int(10) unsigned DEFAULT NULL,
  `is_hidden` tinyint(1) NOT NULL DEFAULT 0,
  `action` varchar(80) NOT NULL,
  `entity_type` varchar(40) DEFAULT NULL,
  `entity_id` int(10) unsigned DEFAULT NULL,
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`metadata`)),
  `ip` varchar(45) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `audit_logs_actor_id_created_at_index` (`actor_id`,`created_at`),
  KEY `audit_logs_created_at_index` (`created_at`),
  KEY `audit_logs_action_index` (`action`),
  KEY `audit_logs_entity_type_entity_id_index` (`entity_type`,`entity_id`),
  KEY `audit_logs_is_hidden_created_at_index` (`is_hidden`,`created_at`),
  CONSTRAINT `audit_logs_actor_id_foreign` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `borrowing_batches` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `created_by` int(10) unsigned DEFAULT NULL,
  `record_count` int(10) unsigned NOT NULL DEFAULT 0,
  `notes` varchar(500) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `borrowing_batches_created_by_foreign` (`created_by`),
  CONSTRAINT `borrowing_batches_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `borrowing_signatures` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `borrowing_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `signature_path` varchar(255) NOT NULL,
  `sha256` varchar(64) NOT NULL,
  `signed_at` datetime NOT NULL,
  `captured_by` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `borrowing_signatures_borrowing_id_unique` (`borrowing_id`),
  KEY `borrowing_signatures_user_id_foreign` (`user_id`),
  KEY `borrowing_signatures_captured_by_foreign` (`captured_by`),
  CONSTRAINT `borrowing_signatures_borrowing_id_foreign` FOREIGN KEY (`borrowing_id`) REFERENCES `borrowings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `borrowing_signatures_captured_by_foreign` FOREIGN KEY (`captured_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `borrowing_signatures_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `borrowings` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `item_id` int(10) unsigned NOT NULL,
  `batch_id` int(10) unsigned DEFAULT NULL,
  `quantity` int(10) unsigned NOT NULL DEFAULT 1,
  `borrowed_on` date NOT NULL,
  `due_on` date NOT NULL,
  `status` enum('pending_approval','active','returned','partially_returned','lost','rejected') NOT NULL DEFAULT 'active',
  `notes` varchar(500) DEFAULT NULL,
  `issued_by` int(10) unsigned DEFAULT NULL,
  `returned_on` date DEFAULT NULL,
  `returned_quantity` int(10) unsigned NOT NULL DEFAULT 0,
  `return_condition` varchar(100) DEFAULT NULL,
  `return_notes` varchar(1000) DEFAULT NULL,
  `returned_to` int(10) unsigned DEFAULT NULL,
  `fine_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `fine_overridden` tinyint(1) NOT NULL DEFAULT 0,
  `fine_override_reason` varchar(500) DEFAULT NULL,
  `fine_overridden_by` int(10) unsigned DEFAULT NULL,
  `fine_status` enum('none','pending','paid','waived') NOT NULL DEFAULT 'none',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `approved_by` int(10) unsigned DEFAULT NULL,
  `approved_at` datetime DEFAULT NULL,
  `rejection_reason` varchar(500) DEFAULT NULL,
  `renewals` int(10) unsigned NOT NULL DEFAULT 0,
  `issue_condition` varchar(100) DEFAULT NULL,
  `property_request_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `borrowings_issued_by_foreign` (`issued_by`),
  KEY `borrowings_returned_to_foreign` (`returned_to`),
  KEY `borrowings_fine_overridden_by_foreign` (`fine_overridden_by`),
  KEY `borrowings_user_id_status_index` (`user_id`,`status`),
  KEY `borrowings_item_id_index` (`item_id`),
  KEY `borrowings_status_due_on_index` (`status`,`due_on`),
  KEY `borrowings_due_on_index` (`due_on`),
  KEY `borrowings_batch_id_index` (`batch_id`),
  KEY `borrowings_approved_by_foreign` (`approved_by`),
  CONSTRAINT `borrowings_approved_by_foreign` FOREIGN KEY (`approved_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `borrowings_batch_id_foreign` FOREIGN KEY (`batch_id`) REFERENCES `borrowing_batches` (`id`) ON DELETE SET NULL,
  CONSTRAINT `borrowings_fine_overridden_by_foreign` FOREIGN KEY (`fine_overridden_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `borrowings_issued_by_foreign` FOREIGN KEY (`issued_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `borrowings_item_id_foreign` FOREIGN KEY (`item_id`) REFERENCES `items` (`id`),
  CONSTRAINT `borrowings_returned_to_foreign` FOREIGN KEY (`returned_to`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `borrowings_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `chk_borrow_dates` CHECK (`due_on` >= `borrowed_on`),
  CONSTRAINT `chk_borrow_fine` CHECK (`fine_amount` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `categories` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned DEFAULT NULL,
  `name` varchar(150) NOT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `image` varchar(255) DEFAULT NULL,
  `icon` varchar(60) DEFAULT NULL,
  `display_order` int(11) NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `depth` int(10) unsigned NOT NULL DEFAULT 0,
  `created_by` int(10) unsigned DEFAULT NULL,
  `updated_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `study_on` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `categories_created_by_foreign` (`created_by`),
  KEY `categories_updated_by_foreign` (`updated_by`),
  KEY `categories_parent_id_display_order_index` (`parent_id`,`display_order`),
  KEY `categories_is_active_index` (`is_active`),
  KEY `categories_study_on_index` (`study_on`),
  CONSTRAINT `categories_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `categories_parent_id_foreign` FOREIGN KEY (`parent_id`) REFERENCES `categories` (`id`),
  CONSTRAINT `categories_updated_by_foreign` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `chat_messages` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `department_id` int(10) unsigned NOT NULL,
  `thread_key` varchar(40) NOT NULL,
  `sender_id` int(10) unsigned NOT NULL,
  `recipient_id` int(10) unsigned DEFAULT NULL,
  `kind` enum('text','image','audio','video','file','meeting') NOT NULL DEFAULT 'text',
  `body` text DEFAULT NULL,
  `attachment_path` varchar(255) DEFAULT NULL,
  `attachment_mime` varchar(100) DEFAULT NULL,
  `attachment_size` int(10) unsigned DEFAULT NULL,
  `attachment_name` varchar(150) DEFAULT NULL,
  `meeting_url` varchar(500) DEFAULT NULL,
  `meeting_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `chat_messages_sender_id_foreign` (`sender_id`),
  KEY `chat_messages_deleted_by_foreign` (`deleted_by`),
  KEY `chat_messages_department_id_thread_key_id_index` (`department_id`,`thread_key`,`id`),
  KEY `chat_messages_recipient_id_index` (`recipient_id`),
  CONSTRAINT `chat_messages_deleted_by_foreign` FOREIGN KEY (`deleted_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chat_messages_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chat_messages_recipient_id_foreign` FOREIGN KEY (`recipient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chat_messages_sender_id_foreign` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `chat_reads` (
  `user_id` int(10) unsigned NOT NULL,
  `department_id` int(10) unsigned NOT NULL,
  `thread_key` varchar(40) NOT NULL,
  `last_read_id` bigint(20) unsigned NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`user_id`,`department_id`,`thread_key`),
  KEY `chat_reads_department_id_foreign` (`department_id`),
  CONSTRAINT `chat_reads_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chat_reads_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `choir_eligibility` (
  `user_id` int(10) unsigned NOT NULL,
  `score` decimal(6,2) NOT NULL,
  `eligible` tinyint(1) NOT NULL DEFAULT 0,
  `breakdown` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`breakdown`)),
  `eligible_since` datetime DEFAULT NULL,
  `computed_at` datetime NOT NULL,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `choir_eligibility_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `choir_selections` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `performance_type` enum('wereb_mezmur','mezmur_only') NOT NULL,
  `season` varchar(120) DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `status` enum('active','removed') NOT NULL DEFAULT 'active',
  `selected_by` int(10) unsigned DEFAULT NULL,
  `selected_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `choir_selections_selected_by_foreign` (`selected_by`),
  KEY `choir_selections_status_performance_type_index` (`status`,`performance_type`),
  KEY `choir_selections_user_id_index` (`user_id`),
  CONSTRAINT `choir_selections_selected_by_foreign` FOREIGN KEY (`selected_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `choir_selections_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `department_admins` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `department_id` int(10) unsigned NOT NULL,
  `role_id` int(10) unsigned NOT NULL,
  `assigned_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `department_admins_user_id_department_id_role_id_unique` (`user_id`,`department_id`,`role_id`),
  KEY `department_admins_role_id_foreign` (`role_id`),
  KEY `department_admins_assigned_by_foreign` (`assigned_by`),
  KEY `department_admins_department_id_index` (`department_id`),
  CONSTRAINT `department_admins_assigned_by_foreign` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `department_admins_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `department_admins_role_id_foreign` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`),
  CONSTRAINT `department_admins_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `department_participation` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `department_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `period` varchar(7) NOT NULL,
  `note` varchar(300) DEFAULT NULL,
  `recorded_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `score` decimal(4,1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `department_participation_department_id_user_id_period_unique` (`department_id`,`user_id`,`period`),
  KEY `department_participation_recorded_by_foreign` (`recorded_by`),
  KEY `department_participation_user_id_period_index` (`user_id`,`period`),
  CONSTRAINT `department_participation_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `department_participation_recorded_by_foreign` FOREIGN KEY (`recorded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `department_participation_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `department_participation_history` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `department_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `period` varchar(7) NOT NULL,
  `old_score` decimal(4,1) DEFAULT NULL,
  `new_score` decimal(4,1) NOT NULL,
  `note` varchar(300) DEFAULT NULL,
  `changed_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `department_participation_history_department_id_foreign` (`department_id`),
  KEY `department_participation_history_changed_by_foreign` (`changed_by`),
  KEY `department_participation_history_user_id_period_index` (`user_id`,`period`),
  CONSTRAINT `department_participation_history_changed_by_foreign` FOREIGN KEY (`changed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `department_participation_history_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `department_participation_history_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `departments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(150) NOT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `name_en` varchar(150) DEFAULT NULL,
  `sort_order` tinyint(3) unsigned NOT NULL DEFAULT 99,
  PRIMARY KEY (`id`),
  KEY `departments_created_by_foreign` (`created_by`),
  CONSTRAINT `departments_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `device_history` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `device_id` varchar(128) DEFAULT NULL,
  `device_name` varchar(150) DEFAULT NULL,
  `event` enum('bound','login','login_rejected','reset','force_logout') NOT NULL,
  `actor_id` int(10) unsigned DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `device_history_actor_id_foreign` (`actor_id`),
  KEY `device_history_user_id_created_at_index` (`user_id`,`created_at`),
  CONSTRAINT `device_history_actor_id_foreign` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `device_history_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `downloads` (
  `user_id` int(10) unsigned NOT NULL,
  `mezmur_id` int(10) unsigned NOT NULL,
  `with_audio` tinyint(1) NOT NULL DEFAULT 0,
  `content_version` int(10) unsigned NOT NULL DEFAULT 1,
  `downloaded_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`user_id`,`mezmur_id`),
  KEY `downloads_mezmur_id_index` (`mezmur_id`),
  CONSTRAINT `downloads_mezmur_id_foreign` FOREIGN KEY (`mezmur_id`) REFERENCES `mezmurs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `downloads_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_assessments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `course_id` int(10) unsigned NOT NULL,
  `title` varchar(150) NOT NULL,
  `max_score` decimal(8,2) NOT NULL DEFAULT 100.00,
  `weight` decimal(5,2) NOT NULL DEFAULT 0.00,
  `held_on` date DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `edu_assessments_course_id_index` (`course_id`),
  CONSTRAINT `edu_assessments_course_id_foreign` FOREIGN KEY (`course_id`) REFERENCES `edu_courses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_assignments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `course_id` int(10) unsigned NOT NULL,
  `title` varchar(200) NOT NULL,
  `instructions` text DEFAULT NULL,
  `due_at` datetime DEFAULT NULL,
  `max_score` decimal(8,2) NOT NULL DEFAULT 100.00,
  `is_group` tinyint(1) NOT NULL DEFAULT 0,
  `attachment` varchar(255) DEFAULT NULL,
  `created_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `edu_assignments_created_by_foreign` (`created_by`),
  KEY `edu_assignments_course_id_index` (`course_id`),
  CONSTRAINT `edu_assignments_course_id_foreign` FOREIGN KEY (`course_id`) REFERENCES `edu_courses` (`id`) ON DELETE CASCADE,
  CONSTRAINT `edu_assignments_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_attendance` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` int(10) unsigned NOT NULL,
  `session_date` date NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `status` enum('present','late','absent','excused') NOT NULL DEFAULT 'present',
  `via` enum('manual','qr') NOT NULL DEFAULT 'manual',
  `recorded_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `edu_attendance_class_id_session_date_user_id_unique` (`class_id`,`session_date`,`user_id`),
  KEY `edu_attendance_recorded_by_foreign` (`recorded_by`),
  KEY `edu_attendance_user_id_session_date_index` (`user_id`,`session_date`),
  CONSTRAINT `edu_attendance_class_id_foreign` FOREIGN KEY (`class_id`) REFERENCES `edu_classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `edu_attendance_recorded_by_foreign` FOREIGN KEY (`recorded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `edu_attendance_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_class_staff` (
  `class_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `role` enum('attendance_taker') NOT NULL DEFAULT 'attendance_taker',
  PRIMARY KEY (`class_id`,`user_id`,`role`),
  KEY `edu_class_staff_user_id_index` (`user_id`),
  CONSTRAINT `edu_class_staff_class_id_foreign` FOREIGN KEY (`class_id`) REFERENCES `edu_classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `edu_class_staff_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_classes` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(150) NOT NULL,
  `description` varchar(2000) DEFAULT NULL,
  `term` varchar(80) DEFAULT NULL,
  `registration_opens_at` datetime DEFAULT NULL,
  `registration_closes_at` datetime DEFAULT NULL,
  `allow_regular` tinyint(1) NOT NULL DEFAULT 1,
  `allow_distance` tinyint(1) NOT NULL DEFAULT 1,
  `capacity` int(10) unsigned DEFAULT NULL,
  `status` enum('active','archived') NOT NULL DEFAULT 'active',
  `created_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `edu_classes_created_by_foreign` (`created_by`),
  CONSTRAINT `edu_classes_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_courses` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` int(10) unsigned NOT NULL,
  `name` varchar(150) NOT NULL,
  `description` varchar(2000) DEFAULT NULL,
  `teacher_user_id` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `edu_courses_class_id_index` (`class_id`),
  KEY `edu_courses_teacher_user_id_index` (`teacher_user_id`),
  CONSTRAINT `edu_courses_class_id_foreign` FOREIGN KEY (`class_id`) REFERENCES `edu_classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `edu_courses_teacher_user_id_foreign` FOREIGN KEY (`teacher_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_enrollments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `program` enum('regular','distance') NOT NULL DEFAULT 'regular',
  `status` enum('active','withdrawn') NOT NULL DEFAULT 'active',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `edu_enrollments_class_id_user_id_unique` (`class_id`,`user_id`),
  KEY `edu_enrollments_user_id_index` (`user_id`),
  CONSTRAINT `edu_enrollments_class_id_foreign` FOREIGN KEY (`class_id`) REFERENCES `edu_classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `edu_enrollments_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_group_members` (
  `group_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`group_id`,`user_id`),
  KEY `edu_group_members_user_id_index` (`user_id`),
  CONSTRAINT `edu_group_members_group_id_foreign` FOREIGN KEY (`group_id`) REFERENCES `edu_groups` (`id`) ON DELETE CASCADE,
  CONSTRAINT `edu_group_members_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_groups` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `course_id` int(10) unsigned NOT NULL,
  `name` varchar(100) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `edu_groups_course_id_foreign` (`course_id`),
  CONSTRAINT `edu_groups_course_id_foreign` FOREIGN KEY (`course_id`) REFERENCES `edu_courses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_schedule` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` int(10) unsigned NOT NULL,
  `course_id` int(10) unsigned DEFAULT NULL,
  `weekday` tinyint(3) unsigned NOT NULL,
  `starts` varchar(5) NOT NULL,
  `ends` varchar(5) NOT NULL,
  `location` varchar(150) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `edu_schedule_course_id_foreign` (`course_id`),
  KEY `edu_schedule_class_id_index` (`class_id`),
  KEY `edu_schedule_weekday_index` (`weekday`),
  CONSTRAINT `edu_schedule_class_id_foreign` FOREIGN KEY (`class_id`) REFERENCES `edu_classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `edu_schedule_course_id_foreign` FOREIGN KEY (`course_id`) REFERENCES `edu_courses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_scores` (
  `assessment_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `score` decimal(8,2) DEFAULT NULL,
  `remark` varchar(300) DEFAULT NULL,
  `recorded_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`assessment_id`,`user_id`),
  KEY `edu_scores_recorded_by_foreign` (`recorded_by`),
  KEY `edu_scores_user_id_index` (`user_id`),
  CONSTRAINT `edu_scores_assessment_id_foreign` FOREIGN KEY (`assessment_id`) REFERENCES `edu_assessments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `edu_scores_recorded_by_foreign` FOREIGN KEY (`recorded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `edu_scores_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `edu_submissions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `assignment_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `group_id` int(10) unsigned DEFAULT NULL,
  `text` text DEFAULT NULL,
  `file` varchar(255) DEFAULT NULL,
  `file_name` varchar(255) DEFAULT NULL,
  `score` decimal(8,2) DEFAULT NULL,
  `feedback` varchar(2000) DEFAULT NULL,
  `graded_by` int(10) unsigned DEFAULT NULL,
  `graded_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `edu_submissions_assignment_id_user_id_unique` (`assignment_id`,`user_id`),
  KEY `edu_submissions_user_id_foreign` (`user_id`),
  KEY `edu_submissions_graded_by_foreign` (`graded_by`),
  KEY `edu_submissions_group_id_index` (`group_id`),
  CONSTRAINT `edu_submissions_assignment_id_foreign` FOREIGN KEY (`assignment_id`) REFERENCES `edu_assignments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `edu_submissions_graded_by_foreign` FOREIGN KEY (`graded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `edu_submissions_group_id_foreign` FOREIGN KEY (`group_id`) REFERENCES `edu_groups` (`id`) ON DELETE SET NULL,
  CONSTRAINT `edu_submissions_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `favorites` (
  `user_id` int(10) unsigned NOT NULL,
  `mezmur_id` int(10) unsigned NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`user_id`,`mezmur_id`),
  KEY `favorites_mezmur_id_index` (`mezmur_id`),
  CONSTRAINT `favorites_mezmur_id_foreign` FOREIGN KEY (`mezmur_id`) REFERENCES `mezmurs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `favorites_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fcm_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `token` varchar(255) NOT NULL,
  `device_id` varchar(128) DEFAULT NULL,
  `platform` enum('android','ios','web') NOT NULL DEFAULT 'android',
  `last_seen_at` datetime NOT NULL DEFAULT current_timestamp(),
  `invalidated_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `fcm_tokens_token_unique` (`token`),
  KEY `fcm_tokens_user_id_invalidated_at_index` (`user_id`,`invalidated_at`),
  CONSTRAINT `fcm_tokens_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `holiday_selections` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(150) NOT NULL,
  `from_date` date NOT NULL,
  `to_date` date NOT NULL,
  `member_groups` varchar(60) DEFAULT NULL,
  `config` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`config`)),
  `status` enum('draft','open','review','finalized','cancelled') NOT NULL DEFAULT 'draft',
  `created_by` int(10) unsigned DEFAULT NULL,
  `finalized_by` int(10) unsigned DEFAULT NULL,
  `finalized_at` datetime DEFAULT NULL,
  `computed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `holiday_selections_created_by_foreign` (`created_by`),
  KEY `holiday_selections_finalized_by_foreign` (`finalized_by`),
  KEY `holiday_selections_status_index` (`status`),
  CONSTRAINT `holiday_selections_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `holiday_selections_finalized_by_foreign` FOREIGN KEY (`finalized_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `id_sequences` (
  `name` varchar(40) NOT NULL,
  `value` bigint(20) unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `items` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `code` varchar(60) NOT NULL,
  `category` varchar(100) DEFAULT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `quantity` int(10) unsigned NOT NULL DEFAULT 1,
  `available_quantity` int(10) unsigned NOT NULL DEFAULT 1,
  `condition` varchar(100) DEFAULT NULL,
  `status` enum('active','inactive','retired') NOT NULL DEFAULT 'active',
  `image` varchar(255) DEFAULT NULL,
  `location` varchar(200) DEFAULT NULL,
  `notes` varchar(1000) DEFAULT NULL,
  `created_by` int(10) unsigned DEFAULT NULL,
  `updated_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` datetime DEFAULT NULL,
  `domain` enum('mezmur','timhirt') NOT NULL DEFAULT 'mezmur',
  `department_id` int(10) unsigned DEFAULT NULL,
  `direct_borrowable` tinyint(1) NOT NULL DEFAULT 0,
  `max_quantity` int(10) unsigned DEFAULT NULL,
  `max_days` int(10) unsigned DEFAULT NULL,
  `renewable` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `items_code_unique` (`code`),
  KEY `items_created_by_foreign` (`created_by`),
  KEY `items_updated_by_foreign` (`updated_by`),
  KEY `items_name_index` (`name`),
  KEY `items_category_index` (`category`),
  KEY `items_status_index` (`status`),
  KEY `items_domain_index` (`domain`),
  KEY `items_department_id_foreign` (`department_id`),
  CONSTRAINT `items_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `items_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE SET NULL,
  CONSTRAINT `items_updated_by_foreign` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_items_qty` CHECK (`available_quantity` <= `quantity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `member_profiles` (
  `user_id` int(10) unsigned NOT NULL,
  `gender` enum('male','female') DEFAULT NULL,
  `mother_name` varchar(150) DEFAULT NULL,
  `birth_date` date DEFAULT NULL,
  `birth_diocese` varchar(100) DEFAULT NULL,
  `birth_city` varchar(100) DEFAULT NULL,
  `birth_woreda` varchar(60) DEFAULT NULL,
  `birth_kebele` varchar(60) DEFAULT NULL,
  `birth_place_name` varchar(100) DEFAULT NULL,
  `christian_name` varchar(100) DEFAULT NULL,
  `baptism_church` varchar(150) DEFAULT NULL,
  `baptism_date` date DEFAULT NULL,
  `address_woreda` varchar(60) DEFAULT NULL,
  `house_number` varchar(30) DEFAULT NULL,
  `phone_home` varchar(30) DEFAULT NULL,
  `emergency_name` varchar(150) DEFAULT NULL,
  `emergency_phone_home` varchar(30) DEFAULT NULL,
  `emergency_phone_mobile` varchar(30) DEFAULT NULL,
  `abinet_education` enum('qes','deacon','none','other') DEFAULT NULL,
  `abinet_other` varchar(100) DEFAULT NULL,
  `theology_education` enum('masters','degree','diploma','certificate') DEFAULT NULL,
  `secular_education` enum('doctorate','masters','degree','diploma','certificate') DEFAULT NULL,
  `institution_name` varchar(150) DEFAULT NULL,
  `field_of_study` varchar(150) DEFAULT NULL,
  `employer_type` enum('private','government') DEFAULT NULL,
  `profession` varchar(150) DEFAULT NULL,
  `experience_profession` varchar(150) DEFAULT NULL,
  `church_service` varchar(200) DEFAULT NULL,
  `school_name` varchar(150) DEFAULT NULL,
  `confession_father_name` varchar(150) DEFAULT NULL,
  `confession_father_phone` varchar(30) DEFAULT NULL,
  `marital_status` enum('married','single') DEFAULT NULL,
  `marriage_type` enum('teklil','kurban','other') DEFAULT NULL,
  `marriage_other` varchar(100) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`user_id`),
  CONSTRAINT `member_profiles_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mezmur_tags` (
  `mezmur_id` int(10) unsigned NOT NULL,
  `tag_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`mezmur_id`,`tag_id`),
  KEY `mezmur_tags_tag_id_index` (`tag_id`),
  CONSTRAINT `mezmur_tags_mezmur_id_foreign` FOREIGN KEY (`mezmur_id`) REFERENCES `mezmurs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `mezmur_tags_tag_id_foreign` FOREIGN KEY (`tag_id`) REFERENCES `tags` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mezmurs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `lyrics` mediumtext NOT NULL,
  `description` varchar(2000) DEFAULT NULL,
  `category_id` int(10) unsigned DEFAULT NULL,
  `cover_image` varchar(255) DEFAULT NULL,
  `audio_path` varchar(255) DEFAULT NULL,
  `audio_mime` varchar(60) DEFAULT NULL,
  `audio_size` int(10) unsigned DEFAULT NULL,
  `audio_duration_sec` int(10) unsigned DEFAULT NULL,
  `status` enum('draft','published','archived') NOT NULL DEFAULT 'draft',
  `is_featured` tinyint(1) NOT NULL DEFAULT 0,
  `view_count` int(10) unsigned NOT NULL DEFAULT 0,
  `favorite_count` int(10) unsigned NOT NULL DEFAULT 0,
  `download_count` int(10) unsigned NOT NULL DEFAULT 0,
  `content_version` int(10) unsigned NOT NULL DEFAULT 1,
  `published_at` datetime DEFAULT NULL,
  `created_by` int(10) unsigned DEFAULT NULL,
  `updated_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` datetime DEFAULT NULL,
  `youtube_url` varchar(255) DEFAULT NULL,
  `study_on` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `mezmurs_created_by_foreign` (`created_by`),
  KEY `mezmurs_updated_by_foreign` (`updated_by`),
  KEY `mezmurs_title_index` (`title`),
  KEY `mezmurs_category_id_status_index` (`category_id`,`status`),
  KEY `mezmurs_status_published_at_index` (`status`,`published_at`),
  KEY `mezmurs_updated_at_index` (`updated_at`),
  KEY `mezmurs_study_on_index` (`study_on`),
  FULLTEXT KEY `ft_mezmurs_title_lyrics` (`title`,`lyrics`),
  CONSTRAINT `mezmurs_category_id_foreign` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE SET NULL,
  CONSTRAINT `mezmurs_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `mezmurs_updated_by_foreign` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notification_broadcasts` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sender_id` int(10) unsigned DEFAULT NULL,
  `kind` enum('announcement','reminder','program_info','admin_message') NOT NULL,
  `title` varchar(255) NOT NULL,
  `body` varchar(2000) NOT NULL,
  `target_type` enum('user','selected','filter','all') NOT NULL,
  `target_filter` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`target_filter`)),
  `entity_type` varchar(40) DEFAULT NULL,
  `entity_id` int(10) unsigned DEFAULT NULL,
  `recipient_count` int(10) unsigned NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `notification_broadcasts_sender_id_created_at_index` (`sender_id`,`created_at`),
  CONSTRAINT `notification_broadcasts_sender_id_foreign` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `type` enum('admin_message','announcement','program','program_reminder','borrowing','borrowing_due','borrowing_overdue','attendance','advertisement','mezmur','system','education','payment','choir') NOT NULL,
  `title` varchar(255) NOT NULL,
  `body` varchar(2000) NOT NULL,
  `entity_type` varchar(40) DEFAULT NULL,
  `entity_id` int(10) unsigned DEFAULT NULL,
  `data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`data`)),
  `broadcast_id` int(10) unsigned DEFAULT NULL,
  `dedupe_key` varchar(150) DEFAULT NULL,
  `delivery_status` enum('pending','sent','failed','skipped') NOT NULL DEFAULT 'pending',
  `sent_at` datetime DEFAULT NULL,
  `read_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `notifications_dedupe_key_unique` (`dedupe_key`),
  KEY `notifications_broadcast_id_foreign` (`broadcast_id`),
  KEY `notifications_user_id_created_at_index` (`user_id`,`created_at`),
  KEY `notifications_user_id_read_at_index` (`user_id`,`read_at`),
  KEY `notifications_delivery_status_created_at_index` (`delivery_status`,`created_at`),
  KEY `notifications_created_at_index` (`created_at`),
  CONSTRAINT `notifications_broadcast_id_foreign` FOREIGN KEY (`broadcast_id`) REFERENCES `notification_broadcasts` (`id`) ON DELETE SET NULL,
  CONSTRAINT `notifications_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `page_images` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `page_id` int(10) unsigned NOT NULL,
  `path` varchar(255) NOT NULL,
  `caption` varchar(255) DEFAULT NULL,
  `display_order` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `page_images_page_id_display_order_index` (`page_id`,`display_order`),
  CONSTRAINT `page_images_page_id_foreign` FOREIGN KEY (`page_id`) REFERENCES `pages` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pages` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `summary` varchar(500) DEFAULT NULL,
  `cover_image` varchar(255) DEFAULT NULL,
  `content` mediumtext NOT NULL,
  `event_date` datetime DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `cta_label` varchar(80) DEFAULT NULL,
  `cta_action` enum('none','open_program','register_program','open_mezmur','open_category') NOT NULL DEFAULT 'none',
  `cta_target_id` int(10) unsigned DEFAULT NULL,
  `program_id` int(10) unsigned DEFAULT NULL,
  `status` enum('draft','published') NOT NULL DEFAULT 'draft',
  `created_by` int(10) unsigned DEFAULT NULL,
  `updated_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `pages_program_id_foreign` (`program_id`),
  KEY `pages_created_by_foreign` (`created_by`),
  KEY `pages_updated_by_foreign` (`updated_by`),
  KEY `pages_status_index` (`status`),
  CONSTRAINT `pages_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `pages_program_id_foreign` FOREIGN KEY (`program_id`) REFERENCES `programs` (`id`) ON DELETE SET NULL,
  CONSTRAINT `pages_updated_by_foreign` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `password_resets` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `code_hash` varchar(64) NOT NULL,
  `attempts` int(10) unsigned NOT NULL DEFAULT 0,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `password_resets_user_id_expires_at_index` (`user_id`,`expires_at`),
  CONSTRAINT `password_resets_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `payment_rates` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `member_type` enum('student','worker') NOT NULL,
  `monthly_amount` decimal(12,2) NOT NULL,
  `currency` varchar(8) NOT NULL DEFAULT 'ETB',
  `effective_from` date NOT NULL,
  `created_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `payment_rates_created_by_foreign` (`created_by`),
  KEY `payment_rates_member_type_effective_from_index` (`member_type`,`effective_from`),
  CONSTRAINT `payment_rates_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `payments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `period` varchar(7) NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `currency` varchar(8) NOT NULL DEFAULT 'ETB',
  `method` enum('cash','bank','telebirr','other') NOT NULL DEFAULT 'cash',
  `reference` varchar(120) DEFAULT NULL,
  `paid_on` date NOT NULL,
  `receipt` varchar(255) DEFAULT NULL,
  `note` varchar(500) DEFAULT NULL,
  `recorded_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `months` int(10) unsigned NOT NULL DEFAULT 1,
  `coverage_end` varchar(7) NOT NULL,
  `member_type` enum('student','worker') DEFAULT NULL,
  `monthly_rate` decimal(12,2) DEFAULT NULL,
  `status` enum('recorded','verified') NOT NULL DEFAULT 'recorded',
  `verified_by` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `payments_recorded_by_foreign` (`recorded_by`),
  KEY `payments_period_index` (`period`),
  KEY `payments_verified_by_foreign` (`verified_by`),
  KEY `payments_user_id_period_index` (`user_id`,`period`),
  CONSTRAINT `payments_recorded_by_foreign` FOREIGN KEY (`recorded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `payments_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `payments_verified_by_foreign` FOREIGN KEY (`verified_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `permission_requests` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `program_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `reason` varchar(500) DEFAULT NULL,
  `status` enum('pending','approved','rejected','cancelled') NOT NULL DEFAULT 'pending',
  `period_month` varchar(7) NOT NULL,
  `period_quarter` varchar(7) NOT NULL,
  `reviewed_by` int(10) unsigned DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `review_note` varchar(500) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `occurrence_date` date NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `permreq_occurrence_unique` (`program_id`,`occurrence_date`,`user_id`),
  KEY `permission_requests_reviewed_by_foreign` (`reviewed_by`),
  KEY `permission_requests_user_id_period_month_index` (`user_id`,`period_month`),
  KEY `permission_requests_user_id_period_quarter_index` (`user_id`,`period_quarter`),
  KEY `permission_requests_status_created_at_index` (`status`,`created_at`),
  KEY `permreq_program_idx` (`program_id`),
  CONSTRAINT `permission_requests_program_id_foreign` FOREIGN KEY (`program_id`) REFERENCES `programs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `permission_requests_reviewed_by_foreign` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `permission_requests_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `permissions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `key` varchar(80) NOT NULL,
  `group_key` varchar(40) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `permissions_key_unique` (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `profile_change_requests` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `old_full_name` varchar(150) NOT NULL,
  `old_phone` varchar(20) NOT NULL,
  `full_name` varchar(150) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `status` enum('pending','approved','rejected','cancelled') NOT NULL DEFAULT 'pending',
  `reason` varchar(500) DEFAULT NULL,
  `reviewed_by` int(10) unsigned DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `profile_change_requests_reviewed_by_foreign` (`reviewed_by`),
  KEY `profile_change_requests_status_created_at_index` (`status`,`created_at`),
  KEY `profile_change_requests_user_id_status_index` (`user_id`,`status`),
  CONSTRAINT `profile_change_requests_reviewed_by_foreign` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `profile_change_requests_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_categories` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(120) NOT NULL,
  `name_en` varchar(120) DEFAULT NULL,
  `color` varchar(9) DEFAULT NULL,
  `display_order` int(11) NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `program_categories_created_by_foreign` (`created_by`),
  CONSTRAINT `program_categories_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_occurrence_overrides` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `program_id` int(10) unsigned NOT NULL,
  `occurrence_date` date NOT NULL,
  `action` enum('cancelled','rescheduled') NOT NULL,
  `starts_at` datetime DEFAULT NULL,
  `ends_at` datetime DEFAULT NULL,
  `reason` varchar(500) DEFAULT NULL,
  `changed_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `program_occurrence_overrides_program_id_occurrence_date_unique` (`program_id`,`occurrence_date`),
  KEY `program_occurrence_overrides_changed_by_foreign` (`changed_by`),
  CONSTRAINT `program_occurrence_overrides_changed_by_foreign` FOREIGN KEY (`changed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `program_occurrence_overrides_program_id_foreign` FOREIGN KEY (`program_id`) REFERENCES `programs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_participants` (
  `program_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `status` enum('invited','registered','cancelled') NOT NULL DEFAULT 'registered',
  `source` enum('self','admin') NOT NULL DEFAULT 'self',
  `added_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`program_id`,`user_id`),
  KEY `program_participants_added_by_foreign` (`added_by`),
  KEY `program_participants_user_id_index` (`user_id`),
  CONSTRAINT `program_participants_added_by_foreign` FOREIGN KEY (`added_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `program_participants_program_id_foreign` FOREIGN KEY (`program_id`) REFERENCES `programs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `program_participants_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `programs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `image` varchar(255) DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `starts_at` datetime NOT NULL,
  `ends_at` datetime NOT NULL,
  `requires_registration` tinyint(1) NOT NULL DEFAULT 0,
  `requires_attendance` tinyint(1) NOT NULL DEFAULT 1,
  `capacity` int(10) unsigned DEFAULT NULL,
  `audience` enum('all','participants') NOT NULL DEFAULT 'all',
  `status` enum('draft','published','cancelled','completed') NOT NULL DEFAULT 'draft',
  `reminder_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `reminder_days_before` int(10) unsigned NOT NULL DEFAULT 1,
  `reminder_title` varchar(255) DEFAULT NULL,
  `reminder_body` varchar(1000) DEFAULT NULL,
  `created_by` int(10) unsigned DEFAULT NULL,
  `updated_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `event_type` varchar(40) DEFAULT NULL,
  `category_id` int(10) unsigned DEFAULT NULL,
  `recurrence` enum('once','weekly','monthly','ethiopian_days') NOT NULL DEFAULT 'once',
  `monthly_rule` enum('day_of_month','nth_weekday') DEFAULT NULL,
  `recurrence_until` date DEFAULT NULL,
  `member_groups` varchar(60) DEFAULT NULL,
  `ethiopian_days` varchar(60) DEFAULT NULL,
  `is_additional` tinyint(1) NOT NULL DEFAULT 0,
  `counts_for_selection` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `programs_created_by_foreign` (`created_by`),
  KEY `programs_updated_by_foreign` (`updated_by`),
  KEY `programs_status_starts_at_index` (`status`,`starts_at`),
  KEY `programs_starts_at_index` (`starts_at`),
  KEY `programs_ends_at_index` (`ends_at`),
  KEY `programs_category_id_index` (`category_id`),
  KEY `programs_recurrence_index` (`recurrence`),
  CONSTRAINT `programs_category_id_foreign` FOREIGN KEY (`category_id`) REFERENCES `program_categories` (`id`) ON DELETE SET NULL,
  CONSTRAINT `programs_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `programs_updated_by_foreign` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `property_request_events` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `request_id` int(10) unsigned NOT NULL,
  `action` varchar(30) NOT NULL,
  `from_status` varchar(20) DEFAULT NULL,
  `to_status` varchar(20) DEFAULT NULL,
  `quantity` int(10) unsigned DEFAULT NULL,
  `note` varchar(1000) DEFAULT NULL,
  `actor_id` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `property_request_events_actor_id_foreign` (`actor_id`),
  KEY `property_request_events_request_id_index` (`request_id`),
  CONSTRAINT `property_request_events_actor_id_foreign` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `property_request_events_request_id_foreign` FOREIGN KEY (`request_id`) REFERENCES `property_requests` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `property_requests` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `department_id` int(10) unsigned NOT NULL,
  `item_id` int(10) unsigned DEFAULT NULL,
  `item_name` varchar(200) DEFAULT NULL,
  `quantity` int(10) unsigned DEFAULT NULL,
  `purpose` varchar(1000) NOT NULL,
  `needed_on` date DEFAULT NULL,
  `return_on` date DEFAULT NULL,
  `status` enum('draft','submitted','under_review','approved','rejected','issued','partially_issued','returned','cancelled') NOT NULL DEFAULT 'submitted',
  `issued_quantity` int(10) unsigned NOT NULL DEFAULT 0,
  `returned_quantity` int(10) unsigned NOT NULL DEFAULT 0,
  `requested_by` int(10) unsigned DEFAULT NULL,
  `reviewed_by` int(10) unsigned DEFAULT NULL,
  `review_note` varchar(1000) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `property_requests_item_id_foreign` (`item_id`),
  KEY `property_requests_requested_by_foreign` (`requested_by`),
  KEY `property_requests_reviewed_by_foreign` (`reviewed_by`),
  KEY `property_requests_status_created_at_index` (`status`,`created_at`),
  KEY `property_requests_department_id_index` (`department_id`),
  CONSTRAINT `property_requests_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`),
  CONSTRAINT `property_requests_item_id_foreign` FOREIGN KEY (`item_id`) REFERENCES `items` (`id`) ON DELETE SET NULL,
  CONSTRAINT `property_requests_requested_by_foreign` FOREIGN KEY (`requested_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `property_requests_reviewed_by_foreign` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `refresh_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `token_hash` varchar(64) NOT NULL,
  `family_id` varchar(36) NOT NULL,
  `scope` enum('app','system') NOT NULL DEFAULT 'app',
  `device_id` varchar(128) DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `replaced_by` bigint(20) unsigned DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `refresh_tokens_token_hash_unique` (`token_hash`),
  KEY `refresh_tokens_user_id_index` (`user_id`),
  KEY `refresh_tokens_family_id_index` (`family_id`),
  KEY `refresh_tokens_expires_at_index` (`expires_at`),
  CONSTRAINT `refresh_tokens_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `reminders` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `program_id` int(10) unsigned DEFAULT NULL,
  `client_uuid` varchar(36) NOT NULL,
  `title` varchar(255) NOT NULL,
  `note` varchar(500) DEFAULT NULL,
  `remind_at` datetime NOT NULL,
  `repeat` enum('none','daily','weekly') NOT NULL DEFAULT 'none',
  `is_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` datetime DEFAULT NULL,
  `borrowing_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `reminders_user_id_client_uuid_unique` (`user_id`,`client_uuid`),
  UNIQUE KEY `reminders_user_id_program_id_remind_at_unique` (`user_id`,`program_id`,`remind_at`),
  KEY `reminders_program_id_foreign` (`program_id`),
  KEY `reminders_user_id_updated_at_index` (`user_id`,`updated_at`),
  KEY `reminders_borrowing_id_foreign` (`borrowing_id`),
  CONSTRAINT `reminders_borrowing_id_foreign` FOREIGN KEY (`borrowing_id`) REFERENCES `borrowings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reminders_program_id_foreign` FOREIGN KEY (`program_id`) REFERENCES `programs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reminders_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `return_conditions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `label` varchar(100) NOT NULL,
  `marks_lost` tinyint(1) NOT NULL DEFAULT 0,
  `restock` tinyint(1) NOT NULL DEFAULT 1,
  `display_order` int(11) NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `return_conditions_label_unique` (`label`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `role_permissions` (
  `role_id` int(10) unsigned NOT NULL,
  `permission_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`role_id`,`permission_id`),
  KEY `role_permissions_permission_id_foreign` (`permission_id`),
  CONSTRAINT `role_permissions_permission_id_foreign` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `role_permissions_role_id_foreign` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `roles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `slug` varchar(64) NOT NULL,
  `name` varchar(120) NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `level` int(11) NOT NULL,
  `is_hidden` tinyint(1) NOT NULL DEFAULT 0,
  `is_system` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `department_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `roles_slug_unique` (`slug`),
  KEY `roles_level_index` (`level`),
  KEY `roles_department_id_foreign` (`department_id`),
  CONSTRAINT `roles_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `selection_results` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `selection_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `components` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`components`)),
  `base_score` decimal(6,2) NOT NULL,
  `bonus` decimal(5,2) NOT NULL DEFAULT 0.00,
  `total` decimal(6,2) NOT NULL,
  `qualified` tinyint(1) NOT NULL,
  `failed` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`failed`)),
  `missing` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`missing`)),
  `override` enum('qualified','not_qualified') DEFAULT NULL,
  `override_reason` varchar(1000) DEFAULT NULL,
  `overridden_by` int(10) unsigned DEFAULT NULL,
  `overridden_at` datetime DEFAULT NULL,
  `computed_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `selection_results_selection_id_user_id_unique` (`selection_id`,`user_id`),
  KEY `selection_results_user_id_foreign` (`user_id`),
  KEY `selection_results_overridden_by_foreign` (`overridden_by`),
  CONSTRAINT `selection_results_overridden_by_foreign` FOREIGN KEY (`overridden_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `selection_results_selection_id_foreign` FOREIGN KEY (`selection_id`) REFERENCES `holiday_selections` (`id`) ON DELETE CASCADE,
  CONSTRAINT `selection_results_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `settings` (
  `key` varchar(80) NOT NULL,
  `value` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`value`)),
  `updated_by` int(10) unsigned DEFAULT NULL,
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`key`),
  KEY `settings_updated_by_foreign` (`updated_by`),
  CONSTRAINT `settings_updated_by_foreign` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sync_receipts` (
  `user_id` int(10) unsigned NOT NULL,
  `op_id` varchar(36) NOT NULL,
  `status` varchar(20) NOT NULL,
  `result` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`result`)),
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`user_id`,`op_id`),
  KEY `sync_receipts_created_at_index` (`created_at`),
  CONSTRAINT `sync_receipts_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tags` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(80) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `tags_name_unique` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `telegram_link_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `token_hash` varchar(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `telegram_link_tokens_token_hash_unique` (`token_hash`),
  KEY `telegram_link_tokens_user_id_index` (`user_id`),
  CONSTRAINT `telegram_link_tokens_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `telegram_state` (
  `key` varchar(40) NOT NULL,
  `value` bigint(20) NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_departments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `department_id` int(10) unsigned NOT NULL,
  `assigned_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `role` enum('member','leader') NOT NULL DEFAULT 'member',
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_departments_user_id_department_id_unique` (`user_id`,`department_id`),
  KEY `user_departments_assigned_by_foreign` (`assigned_by`),
  KEY `user_departments_department_id_index` (`department_id`),
  CONSTRAINT `user_departments_assigned_by_foreign` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `user_departments_department_id_foreign` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `user_departments_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_permissions` (
  `user_id` int(10) unsigned NOT NULL,
  `permission_id` int(10) unsigned NOT NULL,
  `granted_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`user_id`,`permission_id`),
  KEY `user_permissions_permission_id_foreign` (`permission_id`),
  KEY `user_permissions_granted_by_foreign` (`granted_by`),
  CONSTRAINT `user_permissions_granted_by_foreign` FOREIGN KEY (`granted_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `user_permissions_permission_id_foreign` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `user_permissions_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_preferences` (
  `user_id` int(10) unsigned NOT NULL,
  `notifications_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `audio_autoplay` tinyint(1) NOT NULL DEFAULT 0,
  `download_audio` tinyint(1) NOT NULL DEFAULT 1,
  `theme` enum('system','light','dark') NOT NULL DEFAULT 'system',
  `reminder_time` varchar(5) NOT NULL DEFAULT '18:00',
  `language` varchar(8) NOT NULL DEFAULT 'am',
  `lyrics_font_scale` int(10) unsigned NOT NULL DEFAULT 100,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`user_id`),
  CONSTRAINT `user_preferences_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_preferred_categories` (
  `user_id` int(10) unsigned NOT NULL,
  `category_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`user_id`,`category_id`),
  KEY `user_preferred_categories_category_id_foreign` (`category_id`),
  CONSTRAINT `user_preferred_categories_category_id_foreign` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE CASCADE,
  CONSTRAINT `user_preferred_categories_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `full_name` varchar(150) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `email` varchar(190) DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `profile_image` varchar(255) DEFAULT NULL,
  `status` enum('active','disabled','pending') NOT NULL DEFAULT 'active',
  `account_type` enum('user','admin') NOT NULL DEFAULT 'user',
  `role_id` int(10) unsigned DEFAULT NULL,
  `created_by` int(10) unsigned DEFAULT NULL,
  `device_id` varchar(128) DEFAULT NULL,
  `device_name` varchar(150) DEFAULT NULL,
  `device_bound_at` datetime DEFAULT NULL,
  `token_version` int(10) unsigned NOT NULL DEFAULT 0,
  `failed_login_count` int(10) unsigned NOT NULL DEFAULT 0,
  `locked_until` datetime DEFAULT NULL,
  `last_login_at` datetime DEFAULT NULL,
  `password_changed_at` datetime DEFAULT NULL,
  `must_change_password` tinyint(1) NOT NULL DEFAULT 0,
  `totp_secret_enc` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` datetime DEFAULT NULL,
  `telegram_chat_id` bigint(20) DEFAULT NULL,
  `telegram_username` varchar(64) DEFAULT NULL,
  `telegram_linked_at` datetime DEFAULT NULL,
  `member_uuid` varchar(36) DEFAULT NULL,
  `member_type` enum('student','worker') DEFAULT NULL,
  `member_group` enum('children','youth_adult','married') NOT NULL DEFAULT 'youth_adult',
  `can_login` tinyint(1) NOT NULL DEFAULT 1,
  `membership_status` enum('active','deceased','inactive','university','abroad') NOT NULL DEFAULT 'active',
  `membership_status_date` date DEFAULT NULL,
  `membership_status_detail` varchar(150) DEFAULT NULL,
  `spiritual_level` tinyint(3) unsigned DEFAULT NULL,
  `member_no` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_phone_unique` (`phone`),
  UNIQUE KEY `users_email_unique` (`email`),
  UNIQUE KEY `users_telegram_chat_id_unique` (`telegram_chat_id`),
  UNIQUE KEY `users_member_uuid_unique` (`member_uuid`),
  UNIQUE KEY `users_member_no_unique` (`member_no`),
  KEY `users_role_id_foreign` (`role_id`),
  KEY `users_created_by_foreign` (`created_by`),
  KEY `users_device_id_index` (`device_id`),
  KEY `users_account_type_status_index` (`account_type`,`status`),
  KEY `users_full_name_index` (`full_name`),
  KEY `users_created_at_index` (`created_at`),
  KEY `users_member_group_membership_status_index` (`member_group`,`membership_status`),
  CONSTRAINT `users_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `users_role_id_foreign` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wedding_service_members` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `service_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `status` enum('selected','participated','absent','withdrawn') NOT NULL DEFAULT 'selected',
  `snapshot` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`snapshot`)),
  `note` varchar(500) DEFAULT NULL,
  `selected_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `wedding_service_members_service_id_user_id_unique` (`service_id`,`user_id`),
  KEY `wedding_service_members_user_id_foreign` (`user_id`),
  KEY `wedding_service_members_selected_by_foreign` (`selected_by`),
  CONSTRAINT `wedding_service_members_selected_by_foreign` FOREIGN KEY (`selected_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `wedding_service_members_service_id_foreign` FOREIGN KEY (`service_id`) REFERENCES `wedding_services` (`id`) ON DELETE CASCADE,
  CONSTRAINT `wedding_service_members_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wedding_services` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(200) NOT NULL,
  `service_at` datetime NOT NULL,
  `location` varchar(200) DEFAULT NULL,
  `notes` varchar(2000) DEFAULT NULL,
  `requires_attendance` tinyint(1) NOT NULL DEFAULT 0,
  `min_attendance` decimal(5,2) DEFAULT NULL,
  `requires_exam` tinyint(1) NOT NULL DEFAULT 0,
  `min_exam` decimal(5,2) DEFAULT NULL,
  `lookback_months` int(10) unsigned NOT NULL DEFAULT 3,
  `category_ids` varchar(200) DEFAULT NULL,
  `status` enum('planned','completed','cancelled') NOT NULL DEFAULT 'planned',
  `created_by` int(10) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `wedding_services_created_by_foreign` (`created_by`),
  KEY `wedding_services_service_at_index` (`service_at`),
  CONSTRAINT `wedding_services_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

