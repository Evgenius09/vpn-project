package botapi

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/go-telegram/bot/models"

	"github.com/Evgenius09/vpn-project/backend/internal/telegram"
)

// DecodeUpdate parses a Bot API update. The second result is false for updates
// the bot does not serve: only private chats with people count.
func DecodeUpdate(body []byte) (telegram.Update, bool, error) {
	var update models.Update
	if err := json.Unmarshal(body, &update); err != nil {
		return telegram.Update{}, false, fmt.Errorf("telegram: decode update: %w", err)
	}
	mapped, ok := mapUpdate(&update)
	return mapped, ok, nil
}

func mapUpdate(update *models.Update) (telegram.Update, bool) {
	switch {
	case update.Message != nil:
		return mapMessage(update.ID, update.Message)
	case update.CallbackQuery != nil:
		return mapCallback(update.ID, update.CallbackQuery)
	case update.MyChatMember != nil:
		return mapChatMember(update.ID, update.MyChatMember)
	default:
		return telegram.Update{}, false
	}
}

func mapMessage(id int64, message *models.Message) (telegram.Update, bool) {
	if message.From == nil {
		return telegram.Update{}, false
	}
	mapped, ok := newUpdate(id, telegram.UpdateMessage, *message.From, message.Chat)
	mapped.Text = message.Text
	return mapped, ok
}

func mapCallback(id int64, query *models.CallbackQuery) (telegram.Update, bool) {
	var chat models.Chat
	switch {
	case query.Message.Message != nil:
		chat = query.Message.Message.Chat
	case query.Message.InaccessibleMessage != nil:
		chat = query.Message.InaccessibleMessage.Chat
	default:
		return telegram.Update{}, false
	}
	mapped, ok := newUpdate(id, telegram.UpdateCallback, query.From, chat)
	mapped.CallbackID = query.ID
	mapped.CallbackData = query.Data
	return mapped, ok
}

func mapChatMember(id int64, change *models.ChatMemberUpdated) (telegram.Update, bool) {
	var kind telegram.UpdateKind
	switch change.NewChatMember.Type {
	case models.ChatMemberTypeBanned:
		kind = telegram.UpdateBotBlocked
	case models.ChatMemberTypeMember:
		kind = telegram.UpdateBotUnblocked
	default:
		return telegram.Update{}, false
	}
	return newUpdate(id, kind, change.From, change.Chat)
}

func newUpdate(id int64, kind telegram.UpdateKind, user models.User, chat models.Chat) (telegram.Update, bool) {
	if chat.Type != models.ChatTypePrivate || user.IsBot {
		return telegram.Update{}, false
	}
	return telegram.Update{
		UpdateID:   id,
		Kind:       kind,
		TelegramID: user.ID,
		ChatID:     chat.ID,
		Username:   strings.ToLower(user.Username),
		FirstName:  user.FirstName,
	}, true
}
