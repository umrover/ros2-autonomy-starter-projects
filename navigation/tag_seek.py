from geometry_msgs.msg import Twist

from context import Context
from state_machine.state import State
from state import DoneState, FailState

class TagSeekState(State):
    cur_failed_detections : int = 0

    def on_enter(self, context) -> None:
        pass

    def on_exit(self, context) -> None:
        pass

    def on_loop(self, context) -> State:
        # rover angular and distance tolerances
        DISTANCE_TOLERANCE = 0.995
        ANUGLAR_TOLERANCE = 0.3
        TAG_FAILURE_TOLERANCE = 10

        # TODO: get the tag's location and properties (HINT: use get_fid_data() from context.env)
        tag = context.env.get_fid_data()

        # TODO: if we don't have a tag (None or -1): go to the FailState after TAG_FAILURE_TOLERANCE iterations (HINT: use cur_failed_detections to keep track of the amount of failures)
        if tag is None or tag.tag_id == -1:
            self.cur_failed_detections += 1
        else:
            self.cur_failed_detections = 0
        
        if self.cur_failed_detections >= TAG_FAILURE_TOLERANCE:
            return FailState()

        # TODO: if we are within angular and distance tolerances: go to DoneState (HINT: use tag.x_tag_center_pixel and tag.closeness_metric)
        if tag.closeness_metric < DISTANCE_TOLERANCE and abs(tag.x_tag_center_pixel) < ANUGLAR_TOLERANCE:
            return DoneState()

        # TODO: figure out the Twist command to be applied to move the rover closer to the tag (HINT: Think about how the heading of the rover should be orientated before driving to the tag)
        twist = Twist()
        if tag.closeness_metric >= DISTANCE_TOLERANCE:
            twist.linear.x = 1.0
        if abs(tag.x_tag_center_pixel) >= ANUGLAR_TOLERANCE:
            twist.angular.z = -0.5 * tag.x_tag_center_pixel

        # TODO: send Twist command to rover
        context.rover.send_drive_command(twist)

        # TODO: stay in the TagSeekState (with outcome "working")
        return self