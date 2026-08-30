#pragma once

// C++ Standard Library Headers, std namespace
#include <memory>
#include <functional>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

// OpenCV Headers, cv namespace
#include <opencv2/aruco.hpp>
#include <opencv2/core/mat.hpp>

// ROS Headers, ros namespace
# include <rclcpp/rclcpp.hpp>
#include <sensor_msgs/msg/image.hpp>
#include <sensor_msgs/msg/point_cloud2.hpp>
#include <mrover_autonomy_starter/msg/starter_project_tag.hpp>

namespace mrover_autonomy_starter {

    /**
     *  Starter project perception node
     *
     *  Input:  RGB pixel image data
     *  Output: StarterProjectTag message containing the tag ID, center coordinates, and closeness metric of the ArUco tag closest to the camera
     */
    class Perception : public rclcpp::Node {
    private:
        // Class variable to store pointer to subscriber for image data
        rclcpp::Subscription<sensor_msgs::msg::Image>::ConstSharedPtr mImageSubscriber;

        // Class variable to aruco tag detection dictionary
        cv::Ptr<cv::aruco::Dictionary> mTagDictionary;

        // Class variable that stores the detected corners from detectMarkers()
        std::vector<std::vector<cv::Point2f>> mTagCorners;

        // Class variable that stores the detected IDs from detectMarkers()
        std::vector<int> mTagIds;

        // Class variable that stores the information all detected tags
        std::vector<msg::StarterProjectTag> mTags;

        // Class variable to store pointer to publisher for selected tag
        rclcpp::Publisher<msg::StarterProjectTag>::SharedPtr mTagPublisher;

    public:
        Perception();

        /**
         * Called when we receive a new image message (a new frame) from the camera.
         *
         * @param imageMessage
         */
        void imageCallback(sensor_msgs::msg::Image::ConstSharedPtr const& imageMessage);

        /**
         *  Given an image, detect ArUco tags, and fill the vector full of output messages.
         *
         * @param image Image
         * @param tags  Output vector of tags
         */
        void findTagsInImage(cv::Mat const& image);

        /**
         * Publish the closest tag
         *
         * @param tag Selected tag message
         */
        void publishTag(msg::StarterProjectTag const& tag);

        /**
         *  Given an ArUco tag in pixel space, find a metric for how close we are.
         *
         * @param image         Access to the raw OpenCV image as a matrix
         * @param tagCorners    4-tuple of the tag pixel coordinates representing the corners
         * @return              Closeness metric from rover to the tag (should be between 0 and 1, where 0 is closest, 1 is farthest)
         */
        [[nodiscard]] auto getClosenessMetricFromTagCorners(cv::Mat const& image, std::vector<cv::Point2f> const& tagCorners) -> float;

        /**
         *  Given an ArUco tag in pixel space, find the approximate center in pixel space
         *
         * @param tagCorners    4-tuple of tag pixel coordinates representing the corners
         * @return              2-tuple (x,y) approximate center in pixel space
         */
        [[nodiscard]] auto getCenterFromTagCorners(std::vector<cv::Point2f> const& tagCorners) -> std::pair<float, float>;

        /**
         *  Select the tag closest to the camera. If there isn't any tags, return a "dummy" tag with ID of -1.
         * 
         * @param tags          Vector of tags
         * @return              Center tag
         */
        [[nodiscard]] auto selectTag(std::vector<msg::StarterProjectTag> const& tags) -> msg::StarterProjectTag;
    };

} // namespace mrover_autonomy_starter