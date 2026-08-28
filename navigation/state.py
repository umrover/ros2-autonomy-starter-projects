from abc import ABC, abstractmethod
from typing import List, Optional

from state_machine.state import State
from geometry_msgs.msg import Twist
from tag_seek import TagSeekState

from context import Context


class DoneState(State):
    def on_enter(self, context) -> None:
        pass

    def on_exit(self, context) -> None:
        pass

    def on_loop(self, context) -> State:
        # Stop the rover by sending a zero drive command
        context.rover.send_drive_stop()
        return self


class FailState(State):
    def on_enter(self, context) -> None:
        pass

    def on_exit(self, context) -> None:
        pass

    def on_loop(self, context) -> State:
        # Go back to tag_seek if we see a tag
        tag = context.env.get_fid_data()

        if tag is not None and tag.tag_id != -1:
            return TagSeekState()

        # Stop the rover by sending a zero drive command
        context.rover.send_drive_stop()
        return self
