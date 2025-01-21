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

type Manager struct {
	Clients    map[string]map[*Client]bool
	Register   chan *Client
	Unregister chan *Client
	Broadcast  chan []byte
	mu         sync.Mutex
}

var ManagerInstance = NewManager()

func NewManager() *Manager {
	return &Manager{
		Clients:    make(map[string]map[*Client]bool),
		Register:   make(chan *Client),
		Unregister: make(chan *Client),
		Broadcast:  make(chan []byte),
	}
}

func (m *Manager) Run() {
	for {
		select {
		case client := <-m.Register:
			m.addClient(client)
		case client := <-m.Unregister:
			m.removeClient(client)
		case message := <-m.Broadcast:
			m.broadcastMessage(message)
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

func (m *Manager) broadcastMessage(message []byte) {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, clients := range m.Clients {
		for client := range clients {
			select {
			case client.Send <- message:
			default:
				m.removeClient(client)
			}
		}
	}
}

func (c *Client) ReadPump() {
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
		// Transmite a mensagem para os outros clientes na sala
		ManagerInstance.Broadcast <- append([]byte(c.SimpleID+": "), message...)
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
