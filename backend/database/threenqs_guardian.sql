-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jun 17, 2025 at 01:01 AM
-- Server version: 10.3.39-MariaDB-cll-lve
-- PHP Version: 8.1.32

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `threenqs_guardian`
--

-- --------------------------------------------------------

--
-- Table structure for table `tbl_sensor`
--

CREATE TABLE `tbl_sensor` (
  `sensor_id` int(6) NOT NULL,
  `temperature` decimal(5,2) NOT NULL,
  `humidity` decimal(5,2) NOT NULL,
  `motion_detected` enum('CLEAR','DETECTED') NOT NULL,
  `vibration_detected` enum('CLEAR','DETECTED') NOT NULL,
  `relay_state` enum('OFF','ON') NOT NULL,
  `timestamp` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `tbl_threshold`
--

CREATE TABLE `tbl_threshold` (
  `threshold_id` int(11) NOT NULL,
  `temp_high_threshold` decimal(5,2) NOT NULL,
  `temp_low_threshold` decimal(5,2) NOT NULL,
  `humidity_threshold` decimal(5,2) NOT NULL,
  `auto_relay_control` enum('yes','no') NOT NULL,
  `current_relay_state` varchar(10) DEFAULT 'OFF'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `tbl_threshold`
--

INSERT INTO `tbl_threshold` (`threshold_id`, `temp_high_threshold`, `temp_low_threshold`, `humidity_threshold`, `auto_relay_control`, `current_relay_state`) VALUES
(1, 30.00, 18.00, 99.00, 'yes', 'ON');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_users`
--

CREATE TABLE `tbl_users` (
  `user_id` int(6) NOT NULL,
  `user_email` varchar(20) NOT NULL,
  `user_password` varchar(20) NOT NULL,
  `user_regDate` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `tbl_users`
--

INSERT INTO `tbl_users` (`user_id`, `user_email`, `user_password`, `user_regDate`) VALUES
(1, 'aurora@gmail.com', '8d969eef6ecad3c29a3a', '2025-06-17 00:22:53'),
(2, 'aa@gmail.com', '8d969eef6ecad3c29a3a', '2025-06-17 00:23:53'),
(3, 'bb@gmail.com', '123456', '2025-06-17 00:41:13'),
(4, 'cc@gmail.com', '$2y$10$t64rxUxMGm4d9', '2025-06-17 00:52:30');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_sensor`
--
ALTER TABLE `tbl_sensor`
  ADD PRIMARY KEY (`sensor_id`);

--
-- Indexes for table `tbl_threshold`
--
ALTER TABLE `tbl_threshold`
  ADD PRIMARY KEY (`threshold_id`);

--
-- Indexes for table `tbl_users`
--
ALTER TABLE `tbl_users`
  ADD PRIMARY KEY (`user_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `tbl_sensor`
--
ALTER TABLE `tbl_sensor`
  MODIFY `sensor_id` int(6) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `tbl_users`
--
ALTER TABLE `tbl_users`
  MODIFY `user_id` int(6) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
