package main

import (
	"log"
	"os"
	controller "server/src/controllers"
	"server/src/middlewares"
	"server/src/routes"
	websocketmanager "server/src/websocket"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	if os.Getenv("ENVIRONMENT") != "production" {
		err := godotenv.Load()
		if err != nil {
			log.Println("Warning: .env file not found. Falling back to environment variables.")
		}
	}

	port := os.Getenv("PORT")

	if port == "" {
		port = "8080"
	}
	router := gin.New()

	router.GET("/favicon.ico", func(c *gin.Context) { c.File("favicon.ico") })

	router.Use(gin.Logger())
	router.Use(middlewares.CORS())

	go websocketmanager.ManagerInstance.Run()

	controller.StartImportWorker()
	controller.InitAutoImport()
	controller.StartStatsCollector()
	controller.StartWeeklySync()

	routes.AuthRoutes(router)
	routes.ImageRoutes(router)
	routes.AdminRoutes(router)

	authProtected := router.Group("/")
	authProtected.Use(middlewares.Authenticate())

	routes.StreamRoutes(authProtected)
	routes.UserRoutes(authProtected)
	routes.MusicRoutes(authProtected)
	routes.PlaylistRoutes(authProtected)
	routes.MusicJamRoutes(authProtected)
	routes.GenreRoutes(authProtected)

	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Erro ao iniciar o servidor: %v", err)
	}

	log.Println("port", port)
}
