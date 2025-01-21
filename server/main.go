package main

import (
	"log"
	"os"
	"server/src/routes"
	websocketmanager "server/src/websocket"

	"github.com/gin-gonic/gin"
)

func main() {
	port := os.Getenv("PORT")

	if port == "" {
		port = "8080"
	}

	router := gin.New()
	router.Use(gin.Logger())

	go websocketmanager.ManagerInstance.Run()

	routes.ImageRoutes(router)
	routes.AuthRoutes(router)
	routes.UserRoutes(router)
	routes.MusicRoutes(router)
	routes.MusicJamRoutes(router)

	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Erro ao iniciar o servidor: %v", err)
	}

	log.Println("port", port)
}
