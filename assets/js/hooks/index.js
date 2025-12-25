// Import custom hooks
import { ParticipantStorage } from "./participant_storage"
import { TicketHistory } from "./ticket_history"
import { UserSettings } from "./user_settings"
import { SwipeHandler } from "./swipe_handler"
import { LongPressHandler } from "./long_press_handler"
import { SwipeAndLongPressHandler } from "./swipe_and_long_press_handler"
import { SplitDivider } from "./split_divider"
import { QRCodeGenerator } from "./qr_code_generator"
import { CopyToClipboard } from "./copy_to_clipboard"
import { ImageZoom } from "./image_zoom"
import { ImageCropper } from "./image_cropper"

// Import colocated hooks from phoenix-colocated (actualmente vacíos)
import { hooks as colocatedHooks } from "phoenix-colocated/ticket_splitter"

// Exportar todos los hooks combinados
export const hooks = {
  ...colocatedHooks,  // Hooks generados automáticamente por phoenix-colocated
  ParticipantStorage,
  TicketHistory,
  UserSettings,
  SwipeHandler,
  LongPressHandler,
  SwipeAndLongPressHandler,
  SplitDivider,
  QRCodeGenerator,
  CopyToClipboard,
  ImageZoom,
  ImageCropper
}
