pub const Rect = @import("Rect.zig");
const lo = @import("layout.zig");
pub const Size = lo.Size;
pub const Constraints = lo.Constraints;
pub const EdgeInsets = lo.EdgeInsets;
const an = @import("alignment.zig");
pub const Alignment = an.Alignment;
pub const Horizontal = Alignment.Horizontal;
pub const Vertical = Alignment.Vertical;
pub const UIManager = @import("UIManager.zig");
pub const Widgets = @import("widgets/widgets.zig");
pub const WidgetNode = @import("widgets/WidgetNode.zig");
pub const Label = Widgets.Label;
pub const Panel = Widgets.Panel;
pub const HStack = Widgets.HStack;
pub const VStack = Widgets.VStack;
pub const Button = Widgets.Button;
const event = @import("event.zig");
pub const UIEventKind = event.EventKind;
pub const UIMouseButton = event.MouseButton;
pub const UIEvent = event.Event;

// TODO: [WIDGETS w/ FONTS] lets remove fonts from this call...
// if you need a font store a pointer to it (so they can use different ones if needed)
// TODO: [WIDGETS w/ TEXT] lets make the padding adaptive to insets so they can differ
// and not have hard coded values in layout?
