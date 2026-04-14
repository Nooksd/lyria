package websocketmanager

import (
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

type Client struct {
	Conn     *websocket.Conn
	Send     chan []byte
	UserID   string
	SimpleID string
}

type RoomMessage struct {
	RoomID  string
	Message []byte
	Sender  *Client
}

type Manager struct {
	Clients    map[string]map[*Client]bool
	Register   chan *Client
	Unregister chan *Client
	Broadcast  chan *RoomMessage
	mu         sync.Mutex
}

var ManagerInstance = NewManager()

func NewManager() *Manager {
	return &Manager{
		Clients:    make(map[string]map[*Client]bool),
		Register:   make(chan *Client),
		Unregister: make(chan *Client),
		Broadcast:  make(chan *RoomMessage),
	}
}

func (m *Manager) Run() {
	for {
		select {
		case client := <-m.Register:
			m.addClient(client)
		case client := <-m.Unregister:
			m.removeClient(client)
		case msg := <-m.Broadcast:
			m.broadcastToRoom(msg)
		}
	}
}

func (m *Manager) addClient(client *Client) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.Clients[client.SimpleID]; !exists {
		m.Clients[client.SimpleID] = make(map[*Client]bool)
	}
	m.Clients[client.SimpleID][client] = true
	log.Printf("Cliente registrado: %s (SimpleID: %s)", client.UserID, client.SimpleID)
}

func (m *Manager) removeClient(client *Client) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if clients, exists := m.Clients[client.SimpleID]; exists {
		if _, ok := clients[client]; ok {
			delete(clients, client)
			close(client.Send)
			log.Printf("Cliente desconectado: %s (SimpleID: %s)", client.UserID, client.SimpleID)
			if len(clients) == 0 {
				delete(m.Clients, client.SimpleID)
				log.Printf("SimpleID encerrado: %s", client.SimpleID)
			}
		}
	}
}

func (m *Manager) broadcastToRoom(msg *RoomMessage) {
	m.mu.Lock()
	defer m.mu.Unlock()

	clients, exists := m.Clients[msg.RoomID]
	if !exists {
		return
	}

	for client := range clients {
		if msg.Sender != nil && client == msg.Sender {
			continue
		}
		select {
		case client.Send <- msg.Message:
		default:
			delete(clients, client)
			close(client.Send)
		}
	}
}

func BroadcastToRoom(roomID string, message []byte, sender *Client) {
	ManagerInstance.Broadcast <- &RoomMessage{
		RoomID:  roomID,
		Message: message,
		Sender:  sender,
	}
}

func BroadcastToRoomAll(roomID string, message []byte) {
	ManagerInstance.Broadcast <- &RoomMessage{
		RoomID:  roomID,
		Message: message,
		Sender:  nil,
	}
}

func (c *Client) ReadPump(handler func(client *Client, message []byte)) {
	defer func() {
		ManagerInstance.Unregister <- c
		c.Conn.Close()
	}()

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			log.Printf("Erro ao ler mensagem: %v", err)
			break
		}
		handler(c, message)
	}
}

func (c *Client) WritePump() {
	defer func() {
		c.Conn.Close()
	}()

	for {
		message, ok := <-c.Send
		if !ok {
			c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
			return
		}

		err := c.Conn.WriteMessage(websocket.TextMessage, message)
		if err != nil {
			log.Printf("Erro ao enviar mensagem: %v", err)
			return
		}
	}
}
