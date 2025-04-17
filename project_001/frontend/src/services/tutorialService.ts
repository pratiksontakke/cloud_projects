
import { toast } from "sonner";

export interface Tutorial {
  id?: number;
  title: string;
  description: string;
  published: boolean;
  createdAt?: string;
  updatedAt?: string;
}

// This would be replaced by your actual API URL when deploying
const API_URL = import.meta.env.VITE_API_URL || "http://localhost:8081/api/tutorials";

export const tutorialService = {
  // Get all tutorials with optional title filter
  async getAll(title?: string): Promise<Tutorial[]> {
    try {
      const url = title ? `${API_URL}?title=${encodeURIComponent(title)}` : API_URL;
      const response = await fetch(url);
      
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error("Error fetching tutorials:", error);
      toast.error("Failed to load tutorials");
      return [];
    }
  },

  // Get a single tutorial by ID
  async getById(id: number): Promise<Tutorial | null> {
    try {
      const response = await fetch(`${API_URL}/${id}`);
      
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error(`Error fetching tutorial with ID ${id}:`, error);
      toast.error(`Failed to load tutorial #${id}`);
      return null;
    }
  },

  // Create a new tutorial
  async create(tutorial: Tutorial): Promise<Tutorial | null> {
    try {
      const response = await fetch(API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(tutorial),
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      
      const data = await response.json();
      toast.success("Tutorial created successfully");
      return data;
    } catch (error) {
      console.error("Error creating tutorial:", error);
      toast.error("Failed to create tutorial");
      return null;
    }
  },

  // Update an existing tutorial
  async update(id: number, tutorial: Tutorial): Promise<boolean> {
    try {
      const response = await fetch(`${API_URL}/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(tutorial),
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      
      toast.success("Tutorial updated successfully");
      return true;
    } catch (error) {
      console.error(`Error updating tutorial with ID ${id}:`, error);
      toast.error("Failed to update tutorial");
      return false;
    }
  },

  // Delete a tutorial
  async delete(id: number): Promise<boolean> {
    try {
      const response = await fetch(`${API_URL}/${id}`, {
        method: 'DELETE',
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      
      toast.success("Tutorial deleted successfully");
      return true;
    } catch (error) {
      console.error(`Error deleting tutorial with ID ${id}:`, error);
      toast.error("Failed to delete tutorial");
      return false;
    }
  },

  // Delete all tutorials
  async deleteAll(): Promise<boolean> {
    try {
      const response = await fetch(API_URL, {
        method: 'DELETE',
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      
      toast.success("All tutorials deleted successfully");
      return true;
    } catch (error) {
      console.error("Error deleting all tutorials:", error);
      toast.error("Failed to delete all tutorials");
      return false;
    }
  },

  // Get all published tutorials
  async findAllPublished(): Promise<Tutorial[]> {
    try {
      const response = await fetch(`${API_URL}/published`);
      
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error("Error fetching published tutorials:", error);
      toast.error("Failed to load published tutorials");
      return [];
    }
  },
};
