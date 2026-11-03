package telegram

import "fmt"

const messageNoUsername = "В вашем профиле нет ника. Задайте его в настройках Telegram и отправьте /start ещё раз: по нику приложение находит ваш аккаунт."

func startMessage(username string) string {
	return fmt.Sprintf("Готово, теперь введите ваш ник @%s в приложении. Код входа придёт сюда.", username)
}
