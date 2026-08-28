#include "perception.hpp"

// ROS Headers, ros namespace
#include <cmath>
#include <functional>
#include <iterator>
#include <limits>
#include <memory>
#include <numeric>
#include <opencv2/aruco.hpp>
#include <opencv2/core.hpp>
#include <opencv2/core/mat.hpp>
#include <opencv2/core/types.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>

auto main(int argc, char** argv) -> int {
    rclcpp::init(argc, argv);

    // "spin" blocks until our node dies
    rclcpp::spin(std::make_shared<mrover_autonomy_starter::Perception>());
    rclcpp::shutdown();

    return EXIT_SUCCESS;
}

namespace mrover_autonomy_starter {

    // Constructor for the perception() node 
    Perception::Perception() : Node("perception") {
        // Subscriber to the input images from the ZED camera.
        // Every time a node publishes to /zed/left/image, the lambda callback we passed will be called, effectively calling imageCallback.
        mImageSubscriber = create_subscription<sensor_msgs::msg::Image>("/zed/left/image", 1, [this](sensor_msgs::msg::Image::ConstSharedPtr const& frame) {
            imageCallback(frame);
        });

        // Create a publisher for our tag topic
        // See: http://wiki.ros.org/ROS/Tutorials/WritingPublisherSubscriber%28c%2B%2B%29
        // TODO: uncomment me!
        // mTagPublisher = create_publisher<msg::StarterProjectTag>("tag", 1);

        // In order for future calls to cv::aruco::detectMarkers to work, we must first get the ArUco dictionary for 4x4 tags with ids from 0-49.
        mTagDictionary = cv::makePtr<cv::aruco::Dictionary>(cv::aruco::getPredefinedDictionary(cv::aruco::DICT_4X4_50));
    }

    auto Perception::imageCallback(sensor_msgs::msg::Image::ConstSharedPtr const& imageMessage) -> void {
        // Create a cv::Mat from the ROS image message
        // Note this does not copy the image data, it is basically a small header that points to the actual image data
        cv::Mat imageBGRA{static_cast<int>(imageMessage->height), static_cast<int>(imageMessage->width),
                      CV_8UC4, const_cast<uint8_t*>(imageMessage->data.data())};
        cv::Mat image;

        // Convert from BGRA to BGR by removing the alpha (transparency) channel since it isn't used
        cv::cvtColor(imageBGRA, image, cv::COLOR_BGRA2BGR);

        // TODO: implement me! Read the wiki and the function header in perception.hpp for more hints.
        (void)this;
    }

    auto Perception::findTagsInImage(cv::Mat const& image) -> void { // NOLINT(*-convert-member-functions-to-static)
        // Take a look at OpenCV's documentation: https://docs.opencv.org/4.5.0/d5/dae/tutorial_aruco_detection.html
        // You have mTagDictionary, mTagCorners, and mTagIds member variables already defined!
        // You might want to call getCenterFromTagCorners() and getClosenessMetricFromTagCorners() within this function

        mTags.clear(); // Clear old tags in output vector

        // TODO: implement me! Read the wiki and the function header in perception.hpp for more hints.
        (void)image;
    }

    auto Perception::selectTag(std::vector<msg::StarterProjectTag> const& tags) -> msg::StarterProjectTag { // NOLINT(*-convert-member-functions-to-static)
        // TODO: implement me! Read the wiki and the function header in perception.hpp for more hints.
        // If there isn't a valid tag, you should return a "dummy" tag with ID -1.
        (void)tags;
        return msg::StarterProjectTag{};
    }

    auto Perception::publishTag(msg::StarterProjectTag const& tag) -> void {
        // TODO: implement me! Read the wiki and the function header in perception.hpp for more hints.
        (void)tag;

    }

    auto Perception::getClosenessMetricFromTagCorners(cv::Mat const& image, std::vector<cv::Point2f> const& tagCorners) -> float { // NOLINT(*-convert-member-functions-to-static)
        // The closeness metric is an approximation that will be used later by navigation to stop "close enough" to a tag.
        // The closeness metric should be between 0 and 1, where 0 is very close and 1 is far away
        // Try not overthink, this metric does not have to be perfect, just somewhat correlated to distance away from a tag
        // Be creative!

        // TODO: implement me! Read the wiki and the function header in perception.hpp for more hints.
        (void)image;
        (void)tagCorners;
        return {};
    }

    auto Perception::getCenterFromTagCorners(std::vector<cv::Point2f> const& tagCorners) -> std::pair<float, float> { // NOLINT(*-convert-member-functions-to-static)
        // TODO: implement me! Read the wiki and the function header in perception.hpp for more hints.
        (void)tagCorners;
        return {};
    }

} // namespace mrover_autonomy_starter