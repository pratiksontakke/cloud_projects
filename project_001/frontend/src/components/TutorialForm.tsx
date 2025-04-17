
import React, { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Tutorial } from "@/services/tutorialService";

interface TutorialFormProps {
  tutorial?: Tutorial | null;
  onSubmit: (tutorial: Tutorial) => void;
  onCancel: () => void;
}

const TutorialForm: React.FC<TutorialFormProps> = ({
  tutorial,
  onSubmit,
  onCancel,
}) => {
  const [formData, setFormData] = useState<Tutorial>({
    title: "",
    description: "",
    published: false,
  });

  const [errors, setErrors] = useState({
    title: "",
  });

  useEffect(() => {
    if (tutorial) {
      setFormData({
        id: tutorial.id,
        title: tutorial.title,
        description: tutorial.description,
        published: tutorial.published,
      });
    }
  }, [tutorial]);

  const handleChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
  ) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    
    // Clear errors
    if (name === "title" && value.trim() !== "") {
      setErrors((prev) => ({ ...prev, title: "" }));
    }
  };

  const handlePublishedChange = (checked: boolean) => {
    setFormData((prev) => ({ ...prev, published: checked }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    // Validate
    if (!formData.title.trim()) {
      setErrors((prev) => ({ ...prev, title: "Title is required" }));
      return;
    }
    
    onSubmit(formData);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4 animate-fade-in">
      <div className="space-y-2">
        <Label htmlFor="title">Title</Label>
        <Input
          id="title"
          name="title"
          value={formData.title}
          onChange={handleChange}
          placeholder="Enter tutorial title"
          className={errors.title ? "border-destructive" : ""}
        />
        {errors.title && (
          <p className="text-destructive text-sm">{errors.title}</p>
        )}
      </div>

      <div className="space-y-2">
        <Label htmlFor="description">Description</Label>
        <Textarea
          id="description"
          name="description"
          value={formData.description || ""}
          onChange={handleChange}
          placeholder="Enter tutorial description"
          rows={4}
        />
      </div>

      <div className="flex items-center space-x-2">
        <Switch
          id="published"
          checked={formData.published}
          onCheckedChange={handlePublishedChange}
        />
        <Label htmlFor="published">Published</Label>
      </div>

      <div className="flex gap-2 justify-end pt-2">
        <Button type="button" variant="outline" onClick={onCancel}>
          Cancel
        </Button>
        <Button type="submit" className="bg-scientific-purple hover:bg-scientific-purple/90">
          {tutorial?.id ? "Update" : "Create"} Tutorial
        </Button>
      </div>
    </form>
  );
};

export default TutorialForm;
