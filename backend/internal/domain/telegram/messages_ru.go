package telegram

import "fmt"

const (
	messageNoUsername    = "В вашем профиле нет ника. Задайте его в настройках Telegram и отправьте /start ещё раз: по нику приложение находит ваш аккаунт."
	messageUnknownDevice = "неизвестное устройство"
)

func startMessage(username string) string {
	return fmt.Sprintf("Готово, теперь введите ваш ник @%s в приложении. Код входа придёт сюда.", username)
}

// CodeMessage is the login code message. An empty model means the client sent
// nothing readable.
func CodeMessage(code, model string) string {
	if model == "" {
		model = messageUnknownDevice
	}
	return fmt.Sprintf("Код входа: %s\nУстройство: %s\n\nЕсли это не вы — проигнорируйте сообщение.", code, model)
}
